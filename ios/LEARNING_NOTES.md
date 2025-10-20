# iOS Development Learning Notes

## Overview
This document tracks my learning progress for iOS development, focusing on Swift, CoreBluetooth, and Bluetooth mesh networking for the bitpoints.me project.

## Phase 1: Development Environment Setup

### Required Tools Installation Status
- [ ] **Xcode**: Download from Mac App Store (~15GB) - REQUIRED for iOS development
- [ ] **Homebrew**: Package manager for macOS - `sudo` access needed
- [ ] **Node.js**: Via Homebrew - `brew install node`
- [ ] **CocoaPods**: iOS dependency manager - `sudo gem install cocoapods`

### Project Setup Commands (after tools installed)
```bash
cd /Users/dayi/git/bitpoints.me
npm install                    # Install Node dependencies
npx cap sync ios              # Sync Capacitor
cd ios/App && pod install     # Install iOS dependencies
open ios/App/App.xcworkspace  # Open in Xcode (use .xcworkspace!)
```

## Phase 2: Swift Fundamentals

### Key Concepts to Master

#### 1. Swift Language Basics
- **Optionals**: `String?`, `if let`, `guard let`, `??` nil coalescing
- **Protocols**: Define interfaces, `protocol`, `extension`
- **Extensions**: Add functionality to existing types
- **Closures**: `{ (param) -> ReturnType in ... }`
- **Memory Management**: ARC, `weak`, `strong`, `unowned`

#### 2. CoreBluetooth Framework
- **CBCentralManager**: Scan for and connect to peripherals
- **CBPeripheralManager**: Advertise and serve as peripheral
- **CBPeripheral**: Connected device with services/characteristics
- **CBCharacteristic**: Read/write data points
- **Background Modes**: `bluetooth-central`, `bluetooth-peripheral`

#### 3. Capacitor Plugin Development
- **CAPPlugin**: Base class for native plugins
- **CAPPluginCall**: Bridge between JS and native
- **notifyEvent()**: Send events to frontend
- **resolve()/reject()**: Return results to JS

## Phase 3: Reference Materials

### BitChat Repository (Primary Reference)
**Location**: `/Users/dayi/git/bitchat/`

**Key Files to Study**:
1. `bitchat/Services/BLEService.swift` - Complete iOS Bluetooth mesh
2. `bitchat/Services/NoiseProtocol.swift` - Full Noise Protocol implementation
3. `bitchat/Models/` - Message and packet data models
4. `WHITEPAPER.md` - Technical architecture
5. `BRING_THE_NOISE.md` - Noise Protocol details

### Bitpoints Current Implementation
**Location**: `/Users/dayi/git/bitpoints.me/ios/App/App/`

**Existing Files**:
- `Plugins/BluetoothEcashPlugin/BluetoothEcashPlugin.swift` - Capacitor bridge
- `Services/BluetoothEcashService.swift` - Main service (7k lines)
- `Services/BLEService.swift` - Core Bluetooth (18k lines)
- `Noise/NoiseProtocol.swift` - Basic structure
- `Models/` - Data models (BitchatPacket, EcashMessage, PeerInfo)

### Android Reference (for ecash logic)
**Location**: `/Users/dayi/git/bitpoints.me/android/app/src/main/java/me/bitpoints/wallet/`

**Key Files**:
- `BluetoothEcashPlugin.kt` - Native plugin
- `BluetoothEcashService.kt` - Token service
- `mesh/` directory - 17 mesh networking files
- `noise/` directory - 5 encryption files

## Phase 4: Architecture Analysis

### What Exists in iOS
- ✅ Basic BLE scanning and advertising
- ✅ Noise Protocol structure (needs crypto implementation)
- ✅ Data models (BitchatPacket, PeerID, EcashMessage)
- ✅ Capacitor plugin bridge
- ✅ Basic peer discovery

### What's Missing (from Android)
1. **Mesh Networking Components** (17 Android files):
   - ConnectionManager - Track peer connections
   - ConnectionTracker - Connection lifecycle
   - PeerManager - Advanced peer discovery
   - MessageHandler - Message processing logic
   - PacketProcessor - Packet routing
   - PacketRelayManager - Multi-hop relay
   - FragmentManager - Large message fragmentation
   - SecurityManager - Attack prevention
   - StoreForwardManager - Offline message caching
   - PowerManager - Battery optimization
   - BluetoothPacketBroadcaster - Broadcasting logic
   - PeerFingerprintManager - Identity tracking
   - TransferProgressManager - Progress tracking

2. **Noise Protocol Encryption**:
   - Full Curve25519 key exchange
   - ChaCha20-Poly1305 AEAD encryption
   - XX handshake pattern
   - Session management

3. **Message Processing**:
   - Token receive handling
   - Auto-redeem logic
   - Frontend event notifications

## Learning Resources

### Swift Documentation
- [Swift.org Documentation](https://docs.swift.org/swift-book/)
- [Apple's Swift Tour](https://docs.swift.org/swift-book/GuidedTour/GuidedTour.html)
- [Swift Language Guide](https://docs.swift.org/swift-book/LanguageGuide/)

### CoreBluetooth
- [CoreBluetooth Programming Guide](https://developer.apple.com/documentation/corebluetooth)
- [Bluetooth Low Energy Guide](https://developer.apple.com/bluetooth/)
- [Background Execution](https://developer.apple.com/documentation/backgroundtasks)

### Capacitor
- [Capacitor Plugin Guide](https://capacitorjs.com/docs/plugins/creating-plugins)
- [iOS Plugin Development](https://capacitorjs.com/docs/ios/plugins)

### Noise Protocol
- [Noise Protocol Specification](https://noiseprotocol.org/noise.html)
- [Swift Noise Library](https://github.com/nmessage/Noise) (evaluate)

## Progress Tracking

### Week 1 Goals
- [ ] Install Xcode and development tools
- [ ] Set up project dependencies
- [ ] Study Swift fundamentals
- [ ] Explore BitChat reference code

### Week 2 Goals
- [ ] Study CoreBluetooth framework
- [ ] Analyze existing iOS architecture
- [ ] Create architecture mapping document
- [ ] Begin implementation planning

## Notes and Observations

### BitChat Architecture Insights
- Uses CoreBluetooth for BLE mesh networking
- Implements Noise Protocol XX pattern for encryption
- Has comprehensive peer discovery and connection management
- Uses binary protocol for efficient packet transmission
- Implements message fragmentation for large payloads

### Bitpoints Integration Points
- Need to port Android mesh networking to iOS
- Must maintain compatibility with Android implementation
- Focus on ecash token transmission over Bluetooth mesh
- Integrate with existing Capacitor plugin architecture

## Questions and Research Areas

1. **Noise Protocol Implementation**: Should I use CryptoKit or swift-noise library?
2. **Background Processing**: How to handle background BLE operations on iOS?
3. **Cross-Platform Compatibility**: Ensure packet format matches Android exactly
4. **Performance**: Battery optimization strategies for continuous BLE scanning
5. **Security**: Best practices for key management in iOS Keychain

---

**Last Updated**: October 19, 2025
**Next Steps**: Install Xcode and begin Swift fundamentals study
