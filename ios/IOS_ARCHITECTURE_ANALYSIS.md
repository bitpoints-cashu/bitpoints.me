# iOS Architecture Analysis

## Overview
This document analyzes the current iOS implementation in bitpoints.me and maps the Android Bluetooth mesh components to their iOS equivalents, using BitChat as the reference implementation.

## Current iOS Implementation Status

### What Exists (✅ Complete)
- **Basic BLE Infrastructure**: `BLEService.swift` (~18k lines) - Core Bluetooth scanning/advertising
- **Noise Protocol Structure**: `NoiseProtocol.swift` - Basic framework (needs crypto implementation)
- **Data Models**: Complete models for BitchatPacket, EcashMessage, PeerInfo, PeerID
- **Capacitor Plugin**: `BluetoothEcashPlugin.swift` - Bridge between JS and native
- **Service Layer**: `BluetoothEcashService.swift` (~7k lines) - Main ecash service
- **Security**: `KeychainManager.swift` - Secure key storage
- **Utilities**: Compression, data extensions, identity management

### What's Missing (❌ Needs Implementation)
Based on Android implementation (~15k lines across 51 files), the following components need to be ported:

## Android-to-iOS Mapping

### 1. Core Mesh Networking (17 Android files → iOS equivalents)

| Android File | Lines | iOS Equivalent | Status | Priority |
|--------------|-------|----------------|--------|----------|
| `BluetoothMeshService.kt` | 1,245 | `BLEService.swift` (expand) | ⚠️ Partial | HIGH |
| `BluetoothConnectionManager.kt` | 566 | `ConnectionManager.swift` (create) | ❌ Missing | HIGH |
| `BluetoothGattClientManager.kt` | 417 | `BLEService.swift` (integrate) | ⚠️ Partial | HIGH |
| `BluetoothGattServerManager.kt` | 379 | `BLEService.swift` (integrate) | ⚠️ Partial | HIGH |
| `BluetoothConnectionTracker.kt` | 373 | `ConnectionTracker.swift` (create) | ❌ Missing | HIGH |
| `PeerManager.kt` | 542 | `BLEService.swift` (enhance) | ⚠️ Partial | HIGH |
| `MessageHandler.kt` | 619 | `MessageHandler.swift` (create) | ❌ Missing | HIGH |
| `PacketProcessor.kt` | 328 | `PacketProcessor.swift` (create) | ❌ Missing | HIGH |
| `PacketRelayManager.kt` | 173 | `PacketRelayManager.swift` (create) | ❌ Missing | MEDIUM |
| `FragmentManager.kt` | 290 | `FragmentManager.swift` (create) | ❌ Missing | HIGH |
| `SecurityManager.kt` | 394 | `SecurityManager.swift` (create) | ❌ Missing | MEDIUM |
| `StoreForwardManager.kt` | 316 | `StoreForwardManager.swift` (create) | ❌ Missing | LOW |
| `PowerManager.kt` | 362 | `PowerManager.swift` (create) | ❌ Missing | MEDIUM |
| `BluetoothPacketBroadcaster.kt` | 449 | `BluetoothPacketBroadcaster.swift` (create) | ❌ Missing | MEDIUM |
| `PeerFingerprintManager.kt` | 246 | `PeerFingerprintManager.swift` (create) | ❌ Missing | LOW |
| `TransferProgressManager.kt` | 30 | `TransferProgressManager.swift` (create) | ❌ Missing | LOW |
| `BluetoothPermissionManager.kt` | 41 | `PermissionManager.swift` (create) | ❌ Missing | LOW |

### 2. Noise Protocol Encryption (5 Android files → iOS equivalents)

| Android File | Lines | iOS Equivalent | Status | Priority |
|--------------|-------|----------------|--------|----------|
| `NoiseEncryptionService.kt` | 495 | `NoiseEncryptionService.swift` (complete) | ⚠️ Partial | HIGH |
| `NoiseSession.kt` | 732 | `NoiseSession.swift` (create) | ❌ Missing | HIGH |
| `NoiseSessionManager.kt` | 226 | `NoiseSessionManager.swift` (create) | ❌ Missing | HIGH |
| `EncryptionService.kt` | 416 | `EncryptionService.swift` (create) | ❌ Missing | MEDIUM |
| 29 Noise library files | ~12k | Use CryptoKit or swift-noise | ❌ Missing | HIGH |

### 3. Protocol & Models (13 Android files → iOS equivalents)

| Android File | Lines | iOS Equivalent | Status | Priority |
|--------------|-------|----------------|--------|----------|
| `BinaryProtocol.kt` | 394 | `BinaryProtocol.swift` (create) | ❌ Missing | HIGH |
| `CompressionUtil.kt` | 174 | `CompressionUtil.swift` (exists) | ✅ Complete | - |
| `MessagePadding.kt` | 78 | `MessagePadding.swift` (exists) | ✅ Complete | - |
| `EcashMessage.kt` | 225 | `EcashMessage.swift` (exists) | ✅ Complete | - |
| `BitchatMessage.kt` | 324 | `BitchatMessage.swift` (create) | ❌ Missing | MEDIUM |
| `FragmentPayload.kt` | 155 | `FragmentPayload.swift` (create) | ❌ Missing | MEDIUM |
| `NoiseEncrypted.kt` | 204 | `NoiseEncrypted.swift` (create) | ❌ Missing | HIGH |
| `IdentityAnnouncement.kt` | 145 | `IdentityAnnouncement.swift` (create) | ❌ Missing | LOW |
| 5 more model files | ~500 | Various model files | ❌ Missing | LOW |

### 4. Sync & Utilities (9 Android files → iOS equivalents)

| Android File | Lines | iOS Equivalent | Status | Priority |
|--------------|-------|----------------|--------|----------|
| `GossipSyncManager.kt` | 264 | `GossipSyncManager.swift` (create) | ❌ Missing | LOW |
| `GCSFilter.kt` | 191 | `GCSFilter.swift` (create) | ❌ Missing | LOW |
| `BinaryEncodingUtils.kt` | 365 | `BinaryEncodingUtils.swift` (create) | ❌ Missing | MEDIUM |
| 6 more utility files | ~400 | Various utilities | ❌ Missing | LOW |

## BitChat Reference Analysis

### Key Insights from BitChat Implementation

**File Structure**:
- `bitchat/Services/BLE/BLEService.swift` (3,689 lines) - Complete iOS BLE mesh implementation
- `bitchat/Services/NoiseEncryptionService.swift` (25,939 lines) - Full Noise Protocol
- `bitchat/Services/UnifiedPeerService.swift` (13,454 lines) - Peer management
- `bitchat/Services/TransportConfig.swift` (9,752 lines) - Configuration constants

**Architecture Patterns**:
1. **Delegate Pattern**: Uses `BitchatDelegate` for UI communication
2. **Publisher Pattern**: `peerSnapshotPublisher` for non-UI services
3. **State Management**: Consolidated peripheral tracking with `PeripheralState`
4. **Fragment Assembly**: `NotificationStreamAssembler` for large messages
5. **Message Deduplication**: `MessageDeduplicator` for replay prevention

**Key Features**:
- Multi-hop relay (up to 7 hops)
- Fragment reassembly for large messages
- Noise Protocol XX pattern with Curve25519
- Background/foreground state management
- Battery optimization with adaptive duty cycling
- Rate limiting and security controls

## Implementation Strategy

### Phase 1: Core Services (Weeks 3-5)
1. **Expand BLEService.swift** - Port logic from BitChat's BLEService
2. **Create ConnectionManager.swift** - Port from Android BluetoothConnectionManager
3. **Create MessageHandler.swift** - Port from Android MessageHandler
4. **Create FragmentManager.swift** - Port from Android FragmentManager

### Phase 2: Noise Protocol (Weeks 5-6)
1. **Complete NoiseEncryptionService.swift** - Port from BitChat's implementation
2. **Create NoiseSession.swift** - Port from Android NoiseSession
3. **Create NoiseSessionManager.swift** - Port from Android NoiseSessionManager
4. **Integrate CryptoKit** - Use Apple's CryptoKit for Curve25519

### Phase 3: Advanced Features (Weeks 6-8)
1. **Create PacketProcessor.swift** - Port from Android PacketProcessor
2. **Create PacketRelayManager.swift** - Port from Android PacketRelayManager
3. **Create SecurityManager.swift** - Port from Android SecurityManager
4. **Create PowerManager.swift** - Port from Android PowerManager

### Phase 4: Integration (Weeks 8-9)
1. **Enhance BluetoothEcashService.swift** - Add token receive handling
2. **Enhance BluetoothEcashPlugin.swift** - Add frontend events
3. **Integrate with transaction history** - Add Bluetooth indicators

## Code Reuse Opportunities

### From BitChat (High Reuse Potential)
- **BLEService.swift** - Core BLE mesh networking (3,689 lines)
- **NoiseEncryptionService.swift** - Complete Noise Protocol (25,939 lines)
- **TransportConfig.swift** - Configuration constants (9,752 lines)
- **MessageDeduplicator.swift** - Replay prevention
- **NotificationStreamAssembler.swift** - Fragment assembly

### From Android (Logic Reference)
- **Connection management patterns**
- **Message routing algorithms**
- **Security controls and rate limiting**
- **Battery optimization strategies**
- **Ecash-specific token handling**

## Technical Considerations

### Dependencies
- **CryptoKit**: Apple's cryptographic framework for Curve25519, ChaCha20-Poly1305
- **CoreBluetooth**: iOS BLE framework
- **Capacitor**: Plugin architecture for JS bridge

### Compatibility Requirements
- **Packet Format**: Must match Android exactly for cross-platform compatibility
- **UUIDs**: Use same service/characteristic UUIDs as Android
- **Noise Protocol**: Same XX pattern implementation
- **Message Types**: Compatible ecash message format

### Performance Considerations
- **Memory Management**: Use ARC properly, avoid retain cycles
- **Background Processing**: Handle iOS background modes correctly
- **Battery Optimization**: Implement adaptive duty cycling
- **Connection Limits**: Max 8 concurrent connections (same as Android)

## Success Metrics

### Functional Requirements
- [ ] iOS ↔ iOS peer discovery and token transfer
- [ ] iOS ↔ Android cross-platform compatibility
- [ ] Multi-hop relay (3+ devices)
- [ ] Noise Protocol handshake success
- [ ] Message fragmentation/reassembly
- [ ] Background operation

### Performance Requirements
- [ ] Battery consumption <10%/hour
- [ ] Connection establishment <5 seconds
- [ ] Message delivery <2 seconds (local)
- [ ] Memory usage <50MB
- [ ] No memory leaks

### Security Requirements
- [ ] Forward secrecy via Noise Protocol
- [ ] Replay attack prevention
- [ ] Rate limiting protection
- [ ] Secure key storage in Keychain
- [ ] Message integrity verification

---

**Last Updated**: October 19, 2025
**Next Steps**: Begin Phase 1 implementation - expand BLEService.swift with BitChat patterns
