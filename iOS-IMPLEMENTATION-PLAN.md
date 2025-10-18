# iOS Bluetooth Mesh Implementation Plan

**Target**: Bitpoints.me v1.1.0-ios  
**Timeline**: 6 weeks  
**Effort**: 1 senior iOS developer full-time  
**Goal**: Feature parity with Android Bluetooth mesh implementation

---

## 🎯 Objectives

Port the complete Android Bluetooth mesh implementation to iOS:
- ✅ Same features as Android
- ✅ Cross-platform compatibility (iOS ↔ Android)
- ✅ Same Noise Protocol encryption
- ✅ Same mesh relay protocol

---

## 📚 Resources Available

### Reference Implementations

**1. Android Implementation** (Complete - 15,000 lines)
- Location: `android/app/src/main/java/me/bitpoints/wallet/`
- Language: Kotlin
- Status: Production-ready, deployed to device

**2. BitChat iOS** (Existing!)
- Location: `../bitchat/bitchat/Services/BLEService.swift`
- Language: Swift
- Status: Battle-tested mesh implementation
- **Key Advantage**: Much of this can be directly adapted!

**3. Documentation**
- `BLUETOOTH_DEVELOPMENT_SUMMARY.md` - Complete implementation guide
- `BLUETOOTH_TESTING_GUIDE.md` - Test procedures
- Android source code is extensively commented

---

## 📋 Week-by-Week Plan

### Week 1: Core BLE Service & Peer Discovery

#### Tasks

**1.1 Set Up iOS Project Structure**
```
ios/Plugin/
  ├── BluetoothEcashPlugin.swift       (Main plugin)
  ├── BluetoothEcashPlugin.m           (ObjC bridge)
  ├── Services/
  │   ├── BluetoothMeshService.swift
  │   └── BLEService.swift
  ├── Managers/
  │   └── PeerManager.swift
  └── Models/
      ├── Peer.swift
      └── EcashMessage.swift
```

**1.2 Port BLE Service from BitChat**

**Source**: `bitchat/bitchat/Services/BLEService.swift`

**Adapt for Cashu**:
```swift
// BitChat has this already - just adapt!
class BLEService: NSObject {
    static let serviceUUID = CBUUID(string: "F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C")
    static let characteristicUUID = CBUUID(string: "A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D")
    
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    // ... rest from BitChat
}
```

**1.3 Implement Peer Discovery**

**Port from**: `android/.../mesh/PeerManager.kt`

```swift
class PeerManager {
    private var peers: [String: Peer] = [:]
    
    func addPeer(_ peer: Peer)
    func removePeer(_ peerID: String)
    func getPeers() -> [Peer]
    func updateLastSeen(_ peerID: String)
}
```

**1.4 Basic Advertising & Scanning**

```swift
func startAdvertising() {
    let advertisementData: [String: Any] = [
        CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
        CBAdvertisementDataLocalNameKey: "BP:\(nickname)"
    ]
    peripheralManager?.startAdvertising(advertisementData)
}

func startScanning() {
    centralManager?.scanForPeripherals(
        withServices: [Self.serviceUUID],
        options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
    )
}
```

#### Deliverables
- [ ] BLE advertising working
- [ ] Peer discovery working
- [ ] Can see nearby iOS devices
- [ ] Peer list updates in real-time

---

### Week 2: GATT Client/Server Implementation

#### Tasks

**2.1 GATT Server (Peripheral Mode)**

**Port from**: `BluetoothGattServerManager.kt`

```swift
class GattServerManager: NSObject, CBPeripheralManagerDelegate {
    private var peripheralManager: CBPeripheralManager?
    private var characteristic: CBMutableCharacteristic?
    
    func setupService() {
        characteristic = CBMutableCharacteristic(
            type: BLEService.characteristicUUID,
            properties: [.write, .notify, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )
        
        let service = CBMutableService(type: BLEService.serviceUUID, primary: true)
        service.characteristics = [characteristic!]
        peripheralManager?.add(service)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, 
                          didReceiveWrite requests: [CBATTRequest]) {
        // Handle incoming data
    }
}
```

**2.2 GATT Client (Central Mode)**

**Port from**: `BluetoothGattClientManager.kt`

```swift
class GattClientManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager?
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    
    func connect(_ peripheral: CBPeripheral) {
        peripheral.delegate = self
        centralManager?.connect(peripheral, options: nil)
    }
    
    func peripheral(_ peripheral: CBPeripheral, 
                   didDiscoverCharacteristicsFor service: CBService, 
                   error: Error?) {
        // Set up notifications
    }
}
```

**2.3 Connection Management**

**Port from**: `BluetoothConnectionManager.kt`

```swift
class ConnectionManager {
    private var connections: [String: Connection] = [:]
    private let maxConnections = 8
    
    func shouldConnect(_ peer: Peer) -> Bool
    func trackConnection(_ peerID: String, _ peripheral: CBPeripheral)
    func closeConnection(_ peerID: String)
}
```

#### Deliverables
- [ ] GATT server accepting connections
- [ ] GATT client connecting to peers
- [ ] Characteristic read/write working
- [ ] Connection tracking operational

---

### Week 3: Noise Protocol Encryption

#### Tasks

**3.1 Evaluate Noise Library Options**

**Option A**: Use SwiftNoise library
```swift
// https://github.com/jedisct1/swift-noise
import Noise

let noise = try NoiseHandshake(pattern: .XX)
```

**Option B**: Port from BitChat's Swift implementation
```swift
// Check if bitchat has Swift Noise implementation
// If so, copy directly
```

**Option C**: Use CryptoKit + manual Noise
```swift
import CryptoKit

// Implement Noise XX pattern manually
// Use CryptoKit for primitives
```

**3.2 Implement NoiseEncryptionService**

**Port from**: `android/.../noise/NoiseEncryptionService.kt`

```swift
class NoiseEncryptionService {
    private var sessions: [String: NoiseSession] = [:]
    
    func encryptMessage(_ data: Data, for peerID: String) -> Data?
    func decryptMessage(_ data: Data, from peerID: String) -> Data?
    func createSession(with peerID: String)
    func destroySession(for peerID: String)
}
```

**3.3 Session Management**

**Port from**: `NoiseSession.kt`, `NoiseSessionManager.kt`

```swift
class NoiseSession {
    let peerID: String
    var handshakeState: HandshakeState?
    var cipherStatePair: CipherStatePair?
    var lastUsed: Date
    
    func performHandshake() throws
    func encrypt(_ data: Data) throws -> Data
    func decrypt(_ data: Data) throws -> Data
}

class NoiseSessionManager {
    private var sessions: [String: NoiseSession] = [:]
    
    func getOrCreateSession(for peerID: String) -> NoiseSession
    func cleanup() // Remove old sessions
}
```

**3.4 Key Management**

```swift
// Store Noise keys in iOS Keychain
class KeychainManager {
    func saveNoiseKeyPair(_ keyPair: Curve25519KeyPair) throws
    func loadNoiseKeyPair() throws -> Curve25519KeyPair
    func generateKeyPair() -> Curve25519KeyPair
}
```

#### Deliverables
- [ ] Noise Protocol library integrated
- [ ] Session creation working
- [ ] Encryption/decryption working
- [ ] Key persistence in Keychain

---

### Week 4: Message Handling & Relay

#### Tasks

**4.1 Message Handler**

**Port from**: `MessageHandler.kt`

```swift
class MessageHandler {
    func handleIncomingMessage(_ data: Data, from peerID: String)
    func processEcashMessage(_ message: EcashMessage)
    func processBitchatMessage(_ message: BitchatMessage)
    func handleFragmentedMessage(_ fragment: FragmentPayload)
}
```

**4.2 Packet Relay Manager**

**Port from**: `PacketRelayManager.kt`

```swift
class PacketRelayManager {
    private var seenPackets: Set<Data> = []
    private let maxTTL = 7
    
    func shouldRelay(_ packet: RoutedPacket) -> Bool {
        guard packet.ttl > 0 else { return false }
        guard !seenPackets.contains(packet.id) else { return false }
        return true
    }
    
    func relayPacket(_ packet: RoutedPacket) {
        var relayedPacket = packet
        relayedPacket.ttl -= 1
        broadcast(relayedPacket)
    }
}
```

**4.3 Fragment Manager**

**Port from**: `FragmentManager.kt`

```swift
class FragmentManager {
    private var incomingFragments: [String: [Int: Data]] = [:]
    private let maxFragmentSize = 512
    
    func fragmentMessage(_ data: Data) -> [FragmentPayload]
    func assembleFragments(_ fragments: [FragmentPayload]) -> Data?
    func cleanupOldFragments()
}
```

**4.4 Packet Processor**

**Port from**: `PacketProcessor.kt`

```swift
class PacketProcessor {
    func processPacket(_ data: Data, from peerID: String) {
        // 1. Decrypt if encrypted
        // 2. Parse packet type
        // 3. Handle fragmentation
        // 4. Route to appropriate handler
        // 5. Relay if TTL > 0
    }
}
```

#### Deliverables
- [ ] Message routing working
- [ ] Fragmentation working (test with >512 byte tokens)
- [ ] Multi-hop relay operational
- [ ] Packet deduplication working

---

### Week 5: Ecash Integration

#### Tasks

**5.1 Capacitor Plugin**

```swift
@objc(BluetoothEcashPlugin)
public class BluetoothEcashPlugin: CAPPlugin {
    private var meshService: BluetoothMeshService?
    private var ecashService: BluetoothEcashService?
    
    @objc func initialize(_ call: CAPPluginCall) {
        let nickname = call.getString("nickname") ?? "Bitpoints User"
        meshService = BluetoothMeshService()
        ecashService = BluetoothEcashService(meshService: meshService!)
        call.resolve(["success": true])
    }
    
    @objc func sendToken(_ call: CAPPluginCall) {
        guard let token = call.getString("token"),
              let recipientID = call.getString("recipientID") else {
            call.reject("Missing parameters")
            return
        }
        
        ecashService?.sendToken(token, to: recipientID) { success in
            call.resolve(["success": success])
        }
    }
    
    @objc func getNearbyPeers(_ call: CAPPluginCall) {
        let peers = meshService?.getPeers() ?? []
        call.resolve(["peers": peers.map { $0.toDictionary() }])
    }
}
```

**5.2 Ecash Service**

**Port from**: `BluetoothEcashService.kt`

```swift
class BluetoothEcashService {
    private let meshService: BluetoothMeshService
    
    func sendToken(_ token: String, to recipientID: String, completion: @escaping (Bool) -> Void) {
        let message = EcashMessage(
            token: token,
            recipientID: recipientID,
            amount: extractAmount(token),
            unit: "sat",
            memo: "",
            timestamp: Date()
        )
        
        let encoded = message.encode()
        meshService.sendMessage(encoded, to: recipientID, type: .ecash)
    }
    
    func handleReceivedToken(_ message: EcashMessage) {
        // Notify frontend via Capacitor event
        notifyListeners("ecashReceived", data: message.toDictionary())
    }
}
```

**5.3 EcashMessage Model**

```swift
struct EcashMessage: Codable {
    let token: String
    let recipientID: String
    let amount: Int
    let unit: String
    let memo: String
    let timestamp: Date
    let senderNpub: String?
    
    func encode() -> Data
    static func decode(_ data: Data) -> EcashMessage?
    func toDictionary() -> [String: Any]
}
```

#### Deliverables
- [ ] BluetoothEcashPlugin.swift complete
- [ ] Token sending working
- [ ] Token receiving working
- [ ] Auto-redeem working
- [ ] Events firing to JavaScript

---

### Week 6: Testing & Cross-Platform Compatibility

#### Tasks

**6.1 iOS ↔ iOS Testing**
- [ ] Two iPhones discover each other
- [ ] Send token from iPhone A → iPhone B
- [ ] Receive and auto-redeem on iPhone B
- [ ] Verify transaction history

**6.2 iOS ↔ Android Testing**
- [ ] iPhone discovers Android device
- [ ] Send token iPhone → Android
- [ ] Send token Android → iPhone
- [ ] Cross-platform multi-hop relay

**6.3 Multi-Device Mesh (3+ devices)**
- [ ] Test with 3 iPhones
- [ ] Test with 2 iPhones + 1 Android
- [ ] Verify TTL decrements correctly
- [ ] Verify packet reaches 3+ hops away

**6.4 Background Testing**
- [ ] App backgrounded - still receives tokens
- [ ] App suspended - receives after resume
- [ ] App killed - misses tokens (expected)

**6.5 Battery Testing**
- [ ] 8-hour test with mesh active
- [ ] Monitor battery drain
- [ ] Optimize if >5% per hour

**6.6 Range Testing**
- [ ] Test maximum distance (direct connection)
- [ ] Test with obstacles (walls, etc.)
- [ ] Verify RSSI-based distance estimation

#### Deliverables
- [ ] All tests passing
- [ ] Cross-platform compatibility verified
- [ ] Battery consumption acceptable
- [ ] Bug fixes applied
- [ ] Ready for TestFlight beta

---

## 📁 Complete File Mapping (Android → iOS)

### Core Services

| Android (Kotlin) | iOS (Swift) | Lines | Priority |
|------------------|-------------|-------|----------|
| `BluetoothMeshService.kt` | `BluetoothMeshService.swift` | ~1,000 | P0 |
| `BluetoothEcashService.kt` | `BluetoothEcashService.swift` | ~350 | P0 |
| `BluetoothEcashPlugin.kt` | `BluetoothEcashPlugin.swift` | ~350 | P0 |

### Managers

| Android (Kotlin) | iOS (Swift) | Lines | Priority |
|------------------|-------------|-------|----------|
| `BluetoothGattClientManager.kt` | `GattClientManager.swift` | ~500 | P0 |
| `BluetoothGattServerManager.kt` | `GattServerManager.swift` | ~400 | P0 |
| `BluetoothConnectionManager.kt` | `ConnectionManager.swift` | ~350 | P0 |
| `BluetoothConnectionTracker.kt` | `ConnectionTracker.swift` | ~350 | P1 |
| `PeerManager.kt` | `PeerManager.swift` | ~500 | P0 |
| `MessageHandler.kt` | `MessageHandler.swift` | ~550 | P0 |
| `PacketProcessor.kt` | `PacketProcessor.swift` | ~300 | P0 |
| `PacketRelayManager.kt` | `PacketRelayManager.swift` | ~150 | P0 |
| `FragmentManager.kt` | `FragmentManager.swift` | ~250 | P0 |
| `SecurityManager.kt` | `SecurityManager.swift` | ~350 | P1 |
| `PowerManager.kt` | `PowerManager.swift` | ~300 | P1 |
| `StoreForwardManager.kt` | `StoreForwardManager.swift` | ~300 | P2 |
| `BluetoothPacketBroadcaster.kt` | `PacketBroadcaster.swift` | ~400 | P0 |
| `PeerFingerprintManager.kt` | `PeerFingerprintManager.swift` | ~220 | P2 |
| `TransferProgressManager.kt` | `TransferProgressManager.swift` | ~30 | P2 |

### Encryption

| Android (Kotlin) | iOS (Swift) | Lines | Priority |
|------------------|-------------|-------|----------|
| `NoiseEncryptionService.kt` | `NoiseEncryptionService.swift` | ~450 | P0 |
| `NoiseSession.kt` | `NoiseSession.swift` | ~650 | P0 |
| `NoiseSessionManager.kt` | `NoiseSessionManager.swift` | ~200 | P0 |
| `NoiseChannelEncryption.kt` | `NoiseChannelEncryption.swift` | ~250 | P0 |
| `EncryptionService.kt` | `EncryptionService.swift` | ~350 | P1 |

**Noise Protocol Library**:
- Use existing Swift library (swift-noise) OR
- Port from Android Java implementation (29 files, ~12,000 lines)

### Protocol & Models

| Android (Kotlin) | iOS (Swift) | Lines | Priority |
|------------------|-------------|-------|----------|
| `BinaryProtocol.kt` | `BinaryProtocol.swift` | ~350 | P0 |
| `EcashMessage.kt` | `EcashMessage.swift` | ~200 | P0 |
| `BitchatMessage.kt` | `BitchatMessage.swift` | ~300 | P0 |
| `FragmentPayload.kt` | `FragmentPayload.swift` | ~150 | P0 |
| `NoiseEncrypted.kt` | `NoiseEncrypted.swift` | ~180 | P0 |
| `IdentityAnnouncement.kt` | `IdentityAnnouncement.swift` | ~130 | P1 |
| `CompressionUtil.kt` | `CompressionUtil.swift` | ~150 | P2 |
| `MessagePadding.kt` | `MessagePadding.swift` | ~70 | P2 |

### Utilities

| Android (Kotlin) | iOS (Swift) | Lines | Priority |
|------------------|-------------|-------|----------|
| `BinaryEncodingUtils.kt` | `BinaryEncodingUtils.swift` | ~300 | P0 |
| `ByteArrayExtensions.kt` | `DataExtensions.swift` | ~50 | P0 |

**Estimated Total**: ~8,000-10,000 lines of Swift code

**Priority Key**:
- P0 = Critical (required for basic functionality)
- P1 = Important (needed for production)
- P2 = Nice to have (can defer)

---

## 🛠️ Development Setup

### Requirements

**Hardware**:
- Mac with macOS 13+ (Ventura or later)
- iPhone 7 or later (iOS 15+)
- 2-3 additional iOS devices for testing
- 1-2 Android devices for cross-platform testing

**Software**:
- Xcode 15+
- CocoaPods or Swift Package Manager
- Node.js 18+
- npm/yarn

**Accounts**:
- Apple Developer account ($99/year)
- Access to GitHub repository

### Initial Setup

**1. Clone Repository**
```bash
cd /path/to/projects
git clone https://github.com/jpgaviria2/cashu.me.git bitpoints
cd bitpoints
git checkout main
```

**2. Install Dependencies**
```bash
npm install
npx cap sync ios
```

**3. Open in Xcode**
```bash
npx cap open ios
```

**4. Add Noise Library** (if using external)
```ruby
# ios/Podfile
pod 'Noise', '~> 1.0'
```

Or add via Swift Package Manager in Xcode.

---

## 🔐 iOS-Specific Considerations

### Permissions (Info.plist)

Already added:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Bitpoints uses Bluetooth to enable offline peer-to-peer token transfers via mesh networking.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>Bitpoints uses Bluetooth to enable offline peer-to-peer token transfers via mesh networking.</string>
```

### Background Modes

**Add to Info.plist**:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>bluetooth-peripheral</string>
</array>
```

**Implications**:
- App can scan in background
- App can advertise in background
- Must implement state preservation/restoration

### State Preservation/Restoration

```swift
// CBCentralManager
centralManager = CBCentralManager(
    delegate: self,
    queue: nil,
    options: [CBCentralManagerOptionRestoreIdentifierKey: "me.bitpoints.wallet.central"]
)

// CBPeripheralManager
peripheralManager = CBPeripheralManager(
    delegate: self,
    queue: nil,
    options: [CBPeripheralManagerOptionRestoreIdentifierKey: "me.bitpoints.wallet.peripheral"]
)

// Implement restoration delegates
func centralManager(_ central: CBCentralManager, 
                   willRestoreState dict: [String: Any]) {
    // Restore scanning state
}
```

### CoreBluetooth vs Android Differences

| Feature | Android | iOS |
|---------|---------|-----|
| **Scan API** | `BluetoothAdapter.startLeScan()` | `CBCentralManager.scanForPeripherals()` |
| **Advertise** | `BluetoothLeAdvertiser` | `CBPeripheralManager.startAdvertising()` |
| **GATT Server** | `BluetoothGattServer` | `CBPeripheralManager` (same object) |
| **GATT Client** | `BluetoothGatt` | `CBPeripheral` |
| **Permissions** | Runtime (Manifest + code) | Info.plist only |
| **Background** | Foreground service | Background modes + restoration |
| **MTU** | Up to 512 (negotiable) | Up to 512 (iOS 11+) |

### Memory Management

**Swift considerations**:
```swift
// Use weak references to avoid retain cycles
weak var delegate: BluetoothDelegate?

// Clean up in deinit
deinit {
    centralManager?.stopScan()
    peripheralManager?.stopAdvertising()
    sessions.removeAll()
}

// Use autoreleasepool for large operations
autoreleasepool {
    // Process large batches of peers
}
```

---

## 🧪 Testing Strategy

### Unit Tests

**Create for each component**:
```swift
// ios/PluginTests/
BluetoothMeshServiceTests.swift
NoiseEncryptionServiceTests.swift
MessageHandlerTests.swift
FragmentManagerTests.swift
PacketRelayManagerTests.swift
```

**Test coverage targets**:
- Core services: 80%+
- Encryption: 90%+
- Message handling: 75%+
- Overall: 80%+

### Integration Tests

**Two-Device Tests**:
1. Peer discovery
2. Token send (iPhone A → iPhone B)
3. Token receive and redeem
4. Encryption handshake
5. Fragment assembly

**Multi-Device Tests**:
1. Three-device relay
2. Five-device mesh
3. Mixed iOS/Android mesh

### Performance Tests

**Metrics to Track**:
- Connection establishment time (<5s target)
- Token transfer time (<10s target)
- Battery drain (<5%/hour target)
- Memory usage (<50MB target)
- Crash-free rate (>99% target)

---

## 📦 Deliverables

### Code
- [ ] ~25 Swift files (~8,000-10,000 lines)
- [ ] Xcode project configured
- [ ] Unit tests (20+ tests)
- [ ] Integration tests (10+ tests)

### Documentation
- [ ] iOS_IMPLEMENTATION_GUIDE.md
- [ ] API_REFERENCE.md (Swift API)
- [ ] iOS-specific troubleshooting guide
- [ ] Updated README with iOS instructions

### Releases
- [ ] TestFlight beta (internal)
- [ ] TestFlight public beta (100 users)
- [ ] App Store submission
- [ ] v1.1.0-ios GitHub release

---

## 💰 Budget Estimate

### Development (6 weeks)

**Senior iOS Developer**:
- Rate: $100-150/hour
- Hours: 40 hours/week × 6 weeks = 240 hours
- **Cost**: $24,000 - $36,000

**Code Review/QA**:
- Rate: $75-100/hour
- Hours: 10 hours/week × 6 weeks = 60 hours
- **Cost**: $4,500 - $6,000

**Total Development**: $28,500 - $42,000

### Infrastructure

- Apple Developer Account: $99/year
- TestFlight (included)
- Server costs: $50/month
- **Total Infrastructure**: ~$700/year

### Alternative: In-House

If you have iOS developers in-house:
- 6 weeks dedicated time
- Access to Mac and iOS devices
- Code review from Android team

---

## 🎯 Success Criteria

### MVP (Minimum Viable Product)

**Must Have**:
- [x] iOS app builds and runs
- [ ] Bluetooth mesh discovers peers
- [ ] Can send token iOS → iOS
- [ ] Can receive and redeem token
- [ ] Basic encryption working
- [ ] No critical bugs

**Nice to Have**:
- Multi-hop relay
- Cross-platform (iOS ↔ Android)
- Background operation
- Store-and-forward

### Production Ready

**Must Have**:
- All MVP features ✅
- Cross-platform compatibility (iOS ↔ Android)
- Multi-hop relay working
- Background operation stable
- Battery drain <5%/hour
- Crash-free rate >99%
- 100+ successful token transfers in testing

**Nice to Have**:
- Store-and-forward tested
- Advanced power optimization
- Network visualization
- Analytics integration

---

## 🚧 Known Challenges

### Challenge 1: Noise Protocol Library

**Issue**: Swift Noise libraries may be limited

**Solutions**:
1. Use swift-noise (if feature-complete)
2. Port BitChat's Swift implementation
3. Bridge to Rust noise library
4. Port from Android Java implementation

**Recommendation**: Check BitChat first, may already have Swift Noise!

### Challenge 2: Background Limitations

**Issue**: iOS is stricter about background Bluetooth

**Solutions**:
- Use background modes correctly
- Implement state preservation
- Test extensively in background
- Graceful degradation if killed

### Challenge 3: Memory Constraints

**Issue**: iOS has stricter memory limits than Android

**Solutions**:
- Use autoreleasepool for batch operations
- Limit cached sessions
- Clean up old peers regularly
- Monitor memory in Instruments

### Challenge 4: Cross-Platform Protocol

**Issue**: Ensuring iOS and Android speak same protocol

**Solutions**:
- Use identical packet format
- Test cross-platform early
- Document protocol spec
- Version negotiation

---

## 📅 Milestones & Checkpoints

### Milestone 1: Week 2 (BLE Working)
**Demo**: iOS device discovers Android device via Bluetooth

**Checkpoint**:
- BLE advertising ✅
- BLE scanning ✅
- Peer discovery ✅
- Connection establishment ✅

### Milestone 2: Week 3 (Encryption Working)
**Demo**: Encrypted message sent between iOS devices

**Checkpoint**:
- Noise handshake ✅
- Session creation ✅
- Encrypt/decrypt ✅
- Key persistence ✅

### Milestone 3: Week 4 (Relay Working)
**Demo**: Message relays through intermediate device

**Checkpoint**:
- TTL decrement ✅
- Packet forwarding ✅
- Deduplication ✅
- 3-device mesh ✅

### Milestone 4: Week 5 (Ecash Working)
**Demo**: Token sent and received on iOS

**Checkpoint**:
- Token serialization ✅
- Send via Bluetooth ✅
- Receive and parse ✅
- Auto-redeem ✅

### Milestone 5: Week 6 (Production Ready)
**Demo**: iOS ↔ Android token transfer working

**Checkpoint**:
- Cross-platform ✅
- All tests passing ✅
- Battery acceptable ✅
- Ready for TestFlight ✅

---

## 🔄 Development Workflow

### Daily

**Morning**:
1. Pull latest from main
2. Review overnight feedback
3. Plan day's tasks

**Development**:
1. Implement one component
2. Write unit tests
3. Test on physical device
4. Commit with clear message

**Evening**:
1. Push code to feature branch
2. Update progress tracker
3. Document any blockers

### Weekly

**Monday**:
- Review previous week
- Plan current week
- Update roadmap if needed

**Friday**:
- Demo progress
- Cross-platform testing
- Code review
- Document learnings

### Code Review Process

**All PRs require**:
1. Unit tests passing
2. Device testing
3. Code review from peer
4. Documentation updated

---

## 📚 Learning Resources

### CoreBluetooth
- [Apple CoreBluetooth Programming Guide](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/)
- [WWDC Videos on Bluetooth](https://developer.apple.com/videos/)

### Noise Protocol
- [Noise Protocol Framework](https://noiseprotocol.org/)
- [Swift Noise Library](https://github.com/jedisct1/swift-noise)

### Reference Implementations
- **BitChat iOS**: `../bitchat/bitchat/Services/BLEService.swift`
- **Android**: `android/app/src/main/java/me/bitpoints/wallet/`
- **Documentation**: All BLUETOOTH_*.md files in repository

---

## 🎉 Summary

**Current State**: Android v1.0.0 production-ready with full Bluetooth mesh

**Next Major Goal**: iOS implementation (6 weeks)

**Strategy**: Port Android implementation to Swift, referencing BitChat iOS BLE code

**Expected Outcome**: Feature-complete iOS app with cross-platform Bluetooth mesh compatibility

**Timeline**: 6 weeks for iOS, then iterative feature additions

---

**Ready to start iOS development? See ios/Plugin/ directory structure above and begin with Week 1!**

*This plan is a living document. Update as development progresses.*



