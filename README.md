# Bitpoints.me

**A Cashu Ecash Wallet with Bluetooth Mesh Networking and Nostr Integration**

> Peer-to-peer payments, offline-first, privacy-focused.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Android](https://img.shields.io/badge/Android-12%2B-green.svg)](https://github.com/bitpoints-cashu/bitpoints.me)
[![Cashu](https://img.shields.io/badge/Cashu-Protocol-orange.svg)](https://github.com/cashubtc)
[![Nostr](https://img.shields.io/badge/Nostr-NIP--04-purple.svg)](https://github.com/nostr-protocol/nips)

## Features

### 💰 Cashu Ecash Wallet
- Full-featured Cashu protocol implementation
- Support for multiple mints
- Token swapping and melting
- Lightning invoices
- QR code send/receive

### 📡 Bluetooth Mesh Networking
- **Peer-to-peer transfers** without internet
- **Mesh relaying** for extended range
- **Encrypted communication** using Noise Protocol
- **Peer discovery** and nickname system
- **Interoperable** with bitchat and other mesh apps

### 🔗 Nostr Integration
- **Auto-claim** tokens received via Nostr
- **Startup recovery** for pending tokens
- **Favorite contacts** with mutual key exchange
- **Direct messaging** with Nostr contacts
- **Plaintext bearer tokens** for simplicity

### 🎯 User Experience
- **Modern UI** with Quasar Framework
- **Always-on service** for background operation
- **Transaction history** with QR recovery
- **Multi-language** support
- **Dark/light themes**

## Installation

### Android APK
Download the latest release from [GitHub Releases](https://github.com/bitpoints-cashu/bitpoints.me/releases)

**Requirements:**
- Android 12 or higher
- ~30 MB storage
- Bluetooth for P2P transfers
- Internet for Nostr and mint access

### Build from Source

```bash
# Clone repository
git clone https://github.com/bitpoints-cashu/bitpoints.me.git
cd bitpoints.me

# Install dependencies
npm install

# Build web assets
npm run build

# Sync with Capacitor
npx cap sync android

# Build Android APK
cd android && ./gradlew assembleRelease
```

## Quick Start

1. **Install** the APK on your Android device
2. **Create wallet** or restore from seed
3. **Add mint** (Trails Coffee mint pre-configured)
4. **Receive ecash** via QR code, Lightning, or Nostr
5. **Send nearby** via Bluetooth mesh
6. **Send contacts** via Nostr messages

## Technology Stack

- **Frontend**: Vue 3 + Quasar + Pinia
- **Android**: Capacitor + Kotlin
- **Cashu**: [cashu-ts](https://github.com/cashubtc/cashu-ts)
- **Nostr**: [NDK](https://github.com/nostr-dev-kit/ndk)
- **Bluetooth**: Custom mesh protocol with Noise encryption
- **Storage**: LocalStorage + IndexedDB

## Architecture

### Bluetooth Mesh
- **GATT-based** communication
- **Noise Protocol** encryption
- **Message relaying** for mesh coverage
- **Peer verification** via public keys
- **Custom packet format** (MESSAGE, ANNOUNCE, SYNC)

### Nostr Messaging
- **NIP-04** direct messages (plaintext tokens)
- **Auto-claim** on receipt
- **24-hour message lookback**
- **Transaction history** backup
- **Mutual favorites** with key exchange

### Auto-Claim System
```
┌─────────────────────────────────┐
│  Nostr Message Received         │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  Parse Cashu Token              │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  Add to History                 │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  Auto-Claim from Mint           │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  Update Balance & Notify        │
└─────────────────────────────────┘
```

## Security

### Cashu Tokens
- **Bearer instruments** - No personal data
- **One-time use** - Cannot be double-spent
- **Mint verification** - All tokens verified by mint

### Bluetooth
- **Noise Protocol** - Modern cryptographic framework
- **Ephemeral keys** - New keys per session
- **Peer verification** - Prevent MITM attacks

### Nostr
- **Key authentication** - Messages signed with Nostr keys
- **No encryption needed** - Bearer tokens don't require encryption
- **Transaction backup** - Always recoverable from history

## Development

### Project Structure
```
bitpoints.me/
├── src/                    # Vue frontend
│   ├── components/         # UI components
│   ├── stores/             # Pinia state management
│   ├── pages/              # Route pages
│   └── plugins/            # Capacitor plugins
├── android/                # Android native code
│   └── app/src/main/java/me/bitpoints/wallet/
│       ├── BluetoothEcashPlugin.kt
│       ├── BluetoothEcashService.kt
│       ├── mesh/           # Bluetooth mesh implementation
│       └── crypto/         # Noise encryption
├── public/                 # Static assets
└── docs/                   # Documentation
```

### Testing
```bash
# Run unit tests
npm run test

# Build debug APK
./android/gradlew assembleDebug

# Install on device
adb install android/app/build/outputs/apk/debug/app-debug.apk

# Monitor logs
adb logcat | grep "BluetoothEcash"
```

## Documentation

- [Bluetooth Implementation](./BLUETOOTH_DEVELOPMENT_SUMMARY.md)
- [Nostr Auto-Claim](./NOSTR_AUTO_CLAIM_IMPLEMENTATION.md)
- [Testing Guide](./BLUETOOTH_TESTING_GUIDE.md)
- [Release Notes](./RELEASE_NOTES_v1.2.0.md)

## Roadmap

### v0.2.0
- [ ] iOS support
- [ ] Web Bluetooth for desktop
- [ ] NIP-17 sealed messages
- [ ] Multi-mint token swaps

### v0.3.0
- [ ] Group payments
- [ ] Token splitting/combining
- [ ] Merchant mode
- [ ] Point-of-sale interface

### v1.0.0
- [ ] Production release
- [ ] App store publishing
- [ ] Full i18n support
- [ ] Advanced privacy features

## Contributing

Contributions welcome! Please read [CONTRIBUTING.md](./CONTRIBUTING.md) first.

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -am 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open Pull Request

## License

MIT License - See [LICENSE.md](LICENSE.md)

## Credits

### Built With
- [Cashu Protocol](https://github.com/cashubtc) - Privacy-focused ecash
- [Nostr Protocol](https://github.com/nostr-protocol/nips) - Decentralized messaging
- [Quasar Framework](https://quasar.dev) - Vue.js UI framework
- [Capacitor](https://capacitorjs.com) - Native app wrapper

### Inspired By
- [bitchat](https://github.com/permissionlesstech/bitchat) - Bluetooth mesh messaging
- [eNuts](https://github.com/cashubtc/eNuts) - Cashu mobile wallet

### Special Thanks
- Cashu community for the amazing protocol
- Nostr community for decentralized infrastructure
- All contributors and testers

## Links

- **Website**: [bitpoints.me](https://bitpoints.me) *(coming soon)*
- **GitHub**: [github.com/bitpoints-cashu/bitpoints.me](https://github.com/bitpoints-cashu/bitpoints.me)
- **Releases**: [GitHub Releases](https://github.com/bitpoints-cashu/bitpoints.me/releases)
- **Issues**: [GitHub Issues](https://github.com/bitpoints-cashu/bitpoints.me/issues)
- **Discussions**: [GitHub Discussions](https://github.com/bitpoints-cashu/bitpoints.me/discussions)

## Contact

- **GitHub**: [@bitpoints-cashu](https://github.com/bitpoints-cashu)
- **Nostr**: `npub...` *(coming soon)*
- **Email**: contact@bitpoints.me *(coming soon)*

---

**Made with ⚡ for the Cashu and Nostr communities**

*"Peer-to-peer payments without permission"*
