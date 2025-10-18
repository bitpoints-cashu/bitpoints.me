# About Bitpoints.me

## The Vision

Bitpoints.me represents a merger of three powerful open-source protocols to create a rewards system that is:
- **Appreciating**: Denominated in Bitcoin, increasing in purchasing power over time
- **Private**: Bearer tokens with no transaction surveillance  
- **Interoperable**: Works with any Bitcoin/Lightning merchant globally
- **Offline-capable**: Peer-to-peer transfers via Bluetooth mesh

## The Protocol Merger

### 1. Cashu Ecash Protocol  

Provides privacy-preserving ecash with blind signatures. The mint cannot link payments to users, ensuring transaction privacy even better than Lightning.

**Learn more**: [cashu.space](https://cashu.space)

### 2. Nostr Identity Protocol

Enables decentralized Lightning addresses (`npub@domain.com`) and social backup without centralized servers. Your identity is yours, not locked to any platform.

**Learn more**: [nostr.how](https://nostr.how)

### 3. Bluetooth Mesh Networking (from BitChat)

Offline peer-to-peer token transfer with Noise Protocol encryption. Multi-hop relay allows reaching peers through intermediate devices (up to 7 hops).

**Inspired by**: [BitChat](https://github.com/jpgaviria2/bitchat) - Battle-tested BLE mesh implementation

## Why These Three Protocols Together?

| Feature | Cashu | Nostr | Bluetooth |
|---------|-------|-------|-----------|
| **Privacy** | ✅ Blind signatures | ✅ Pseudonymous | ✅ Ephemeral IDs |
| **Offline** | ✅ Bearer tokens | ❌ Needs relays | ✅ Local mesh |
| **Interoperable** | ✅ Any mint | ✅ Any relay | ✅ Open protocol |
| **Decentralized** | ⚠️ Mint-based | ✅ Fully p2p | ✅ Mesh topology |

**Together**: Maximum privacy, interoperability, and resilience.

## Appreciating Value: Bitcoin-Denominated Rewards

Traditional points **depreciate** (inflation). Bitcoin-denominated rewards **appreciate** (fixed 21M supply).

Example:
```
2020: 100 sats = 1 cent  →  Buys: 1 piece of candy
2024: 100 sats = 10 cents →  Buys: 1 coffee

Your rewards grew 10x in purchasing power!
```

## Bluetooth Mesh Implementation

Full Android implementation ported from BitChat:

### Core Services
- `BluetoothMeshService.kt` - Main mesh networking service
- `BluetoothEcashPlugin.kt` - Capacitor plugin bridge  
- `BluetoothEcashService.kt` - Token transmission service

### Encryption
- `NoiseEncryptionService.kt` - Noise Protocol (XX pattern)
- `NoiseSession.kt` - Per-peer encryption sessions
- Full Noise Protocol crypto library (Curve25519, ChaCha20-Poly1305)

### Mesh Networking
- `BluetoothGattClientManager.kt` - BLE client operations
- `BluetoothGattServerManager.kt` - BLE server operations
- `MessageHandler.kt` - Ecash message processing
- `PacketRelayManager.kt` - Multi-hop relay (TTL-based)
- `PeerManager.kt` - Peer discovery and tracking

### Protocol
- `BinaryProtocol.kt` - Efficient binary encoding
- `FragmentManager.kt` - Large message fragmentation
- `CompressionUtil.kt` - Message compression

## Open Source Philosophy

Bitpoints.me is built **entirely** on open protocols for maximum interoperability:

1. **Interoperability**: Works with any compatible wallet/mint/relay
2. **No Lock-in**: Users can migrate to any other client
3. **Censorship Resistance**: No single point of failure
4. **Community Development**: Anyone can contribute improvements
5. **Auditability**: Security through transparency

## Security Model

### Threat Model
- User device is trusted
- Mints may be curious but not malicious  
- Network adversaries can observe (but not break crypto)
- Physical Bluetooth range attacks possible

### Mitigations
- Blind signatures prevent mint tracking
- Noise Protocol prevents network eavesdropping
- RSSI gating limits Bluetooth range attacks
- TTL limits prevent infinite relay loops
- Rate limiting prevents spam floods

## Roadmap

### Current (v0.2-beta)
- ✅ Cashu wallet (mint/melt/swap)
- ✅ Nostr identity (NIP-05)
- ✅ Lightning address receiving
- ✅ **Full Bluetooth mesh implementation (Android)**
- ✅ Noise Protocol encryption
- ✅ Multi-hop relay
- ✅ Auto-redeem incoming tokens

### Near-term
- iOS Bluetooth mesh implementation
- Enhanced UI for mesh contacts
- Location-based channels (geohash)
- Social backup (NIP-60)

### Future
- Multiple mint support
- Lightning channel integration
- NFC tap-to-pay (Boltcard)
- Desktop builds (Electron)

## Acknowledgments

Bitpoints.me stands on the shoulders of giants:

- **Calle** and the Cashu community for revolutionary ecash
- **fiatjaf** and Nostr contributors for decentralized identity
- **BitChat** team for robust Bluetooth mesh implementation  
- **Bitcoin/Lightning** developers for the foundation

Thank you to everyone building open protocols for freedom money.

---

**Bitpoints.me** - Open protocols, appreciating rewards, your privacy.

For more information, see [BLUETOOTH_DEVELOPMENT_SUMMARY.md](./BLUETOOTH_DEVELOPMENT_SUMMARY.md).
