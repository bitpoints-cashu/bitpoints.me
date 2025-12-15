# BitPoints Development Roadmap

## Current Status (v0.1.0-bitchat-protocol)
- ✅ Full BitChat protocol implementation with complete packet structure
- ✅ BLE mesh discovery and connection handling
- ✅ Safety fixes for CoreBluetooth crashes
- ✅ Protocol parity with BitChat reference implementation
- ❌ **Known Issue**: BitChat cannot discover BitPoints (one-way only)

## Critical Priority Items

### 🔄 **Interoperability Testing** (High Priority)
**Goal**: Ensure seamless communication between BitChat and BitPoints

- [ ] **Discovery Testing**
  - Test BitPoints discovering BitChat devices ✅ (working)
  - Test BitChat discovering BitPoints devices ❌ (not working)
  - Debug one-way discovery issue
  - Verify advertisement data format matches exactly

- [ ] **Protocol Compliance Testing**
  - Packet encoding/decoding validation
  - TTL and routing behavior
  - Signature validation (when implemented)
  - Connection handshake reliability

### 🔧 **Core Functionality**

- [ ] **Favorites System**
  - Implement peer favoriting in UI
  - Persistent storage of favorite peers
  - Quick connect to favorites
  - Visual indicators for favorites

- [ ] **Bluetooth Reliability**
  - Connection stability improvements
  - Automatic reconnection logic
  - Connection timeout handling
  - Background operation support

- [ ] **Nostr Integration**
  - Nostr protocol implementation
  - Message bridging between BLE and Nostr
  - Identity management (Nostr keys)
  - Cross-network message routing

## Medium Priority Items

### 🛡️ **Security & Privacy**
- [ ] Cryptographic signature validation
- [ ] End-to-end encryption implementation
- [ ] Privacy-preserving discovery
- [ ] Secure key exchange

### 📱 **User Experience**
- [ ] Improved UI/UX for peer discovery
- [ ] Connection status indicators
- [ ] Message history and threading
- [ ] Offline message queuing

### 🔧 **Development Tools**
- [ ] Comprehensive test suite
- [ ] Protocol debugging tools
- [ ] Performance monitoring
- [ ] Automated interoperability tests

## Long-term Goals

### 🌐 **Network Features**
- [ ] Mesh networking improvements
- [ ] Multi-hop message routing
- [ ] Network topology discovery
- [ ] Decentralized identity

### 📊 **Analytics & Monitoring**
- [ ] Usage analytics
- [ ] Network health monitoring
- [ ] Performance metrics
- [ ] Crash reporting

## BitChat Protocol Compliance
**Strict adherence to BitChat reference implementation:**
- ✅ Complete packet structure (BitchatPacket, BinaryProtocol)
- ✅ Proper encoding/decoding with network byte order
- ✅ TTL-based routing
- ✅ Timestamp handling
- ✅ Announcement packet format
- ❌ Full cryptographic implementation (placeholder keys)
- ❌ Signature validation

## Testing Strategy
- [ ] Unit tests for protocol components
- [ ] Integration tests with BitChat reference
- [ ] Cross-device interoperability testing
- [ ] Performance and stress testing
- [ ] Security audits

## Release Milestones
- **v0.2.0**: Full BitChat interoperability
- **v0.3.0**: Favorites and enhanced UX
- **v0.4.0**: Nostr integration
- **v1.0.0**: Production ready with security