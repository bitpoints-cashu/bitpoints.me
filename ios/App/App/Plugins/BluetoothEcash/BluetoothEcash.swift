import Foundation
import CoreBluetooth
import os.log
#if os(iOS)
import UIKit
#endif

// MARK: - BitChat Protocol Structures

/// Simplified BitChat protocol message types.
/// Reduced from 24 types to just 6 essential ones.
/// All private communication metadata (receipts, status) is embedded in noiseEncrypted payloads.
enum MessageType: UInt8 {
    // Public messages (unencrypted)
    case announce = 0x01        // "I'm here" with nickname
    case message = 0x02         // Public chat message
    case leave = 0x03           // "I'm leaving"
    case requestSync = 0x21     // GCS filter-based sync request (local-only)

    // Noise encryption
    case noiseHandshake = 0x10  // Handshake (init or response determined by payload)
    case noiseEncrypted = 0x11  // All encrypted payloads (messages, receipts, etc.)

    // Fragmentation (simplified)
    case fragment = 0x20        // Single fragment type for large messages
    case fileTransfer = 0x22    // Binary file/audio/image payloads

    var description: String {
        switch self {
        case .announce: return "announce"
        case .message: return "message"
        case .leave: return "leave"
        case .requestSync: return "requestSync"
        case .noiseHandshake: return "noiseHandshake"
        case .noiseEncrypted: return "noiseEncrypted"
        case .fragment: return "fragment"
        case .fileTransfer: return "fileTransfer"
        }
    }
}

struct AnnouncementPacket {
    let nickname: String
    let noisePublicKey: Data            // Noise static public key (Curve25519.KeyAgreement)
    let signingPublicKey: Data          // Ed25519 public key for signing
    let directNeighbors: [Data]?        // 8-byte peer IDs

    private enum TLVType: UInt8 {
        case nickname = 0x01
        case noisePublicKey = 0x02
        case signingPublicKey = 0x03
        case directNeighbors = 0x04
    }

    func encode() -> Data? {
        var data = Data()
        // Reserve: TLVs for nickname (2 + n), noise key (2 + 32), signing key (2 + 32)
        data.reserveCapacity(2 + min(nickname.count, 255) + 2 + noisePublicKey.count + 2 + signingPublicKey.count)

        // TLV for nickname
        guard let nicknameData = nickname.data(using: .utf8), nicknameData.count <= 255 else { return nil }
        data.append(TLVType.nickname.rawValue)
        data.append(UInt8(nicknameData.count))
        data.append(nicknameData)

        // TLV for noise public key
        guard noisePublicKey.count <= 255 else { return nil }
        data.append(TLVType.noisePublicKey.rawValue)
        data.append(UInt8(noisePublicKey.count))
        data.append(noisePublicKey)

        // TLV for signing public key
        guard signingPublicKey.count <= 255 else { return nil }
        data.append(TLVType.signingPublicKey.rawValue)
        data.append(UInt8(signingPublicKey.count))
        data.append(signingPublicKey)

        // TLV for direct neighbors (optional)
        if let neighbors = directNeighbors, !neighbors.isEmpty {
            let neighborsData = neighbors.prefix(10).reduce(Data()) { $0 + $1 }
            if !neighborsData.isEmpty && neighborsData.count % 8 == 0 {
                data.append(TLVType.directNeighbors.rawValue)
                data.append(UInt8(neighborsData.count))
                data.append(neighborsData)
            }
        }

        return data
    }

    static func decode(from data: Data) -> AnnouncementPacket? {
        var offset = 0
        var nickname: String?
        var noisePublicKey: Data?
        var signingPublicKey: Data?
        var directNeighbors: [Data]?

        while offset + 2 <= data.count {
            let typeRaw = data[offset]
            offset += 1
            let length = Int(data[offset])
            offset += 1

            guard offset + length <= data.count else { return nil }
            let value = data[offset..<offset + length]
            offset += length

            if let type = TLVType(rawValue: typeRaw) {
                switch type {
                case .nickname:
                    nickname = String(data: value, encoding: .utf8)
                case .noisePublicKey:
                    noisePublicKey = Data(value)
                case .signingPublicKey:
                    signingPublicKey = Data(value)
                case .directNeighbors:
                    if length > 0 && length % 8 == 0 {
                        var neighbors = [Data]()
                        let count = length / 8
                        for i in 0..<count {
                            let start = value.startIndex + i * 8
                            let end = start + 8
                            neighbors.append(Data(value[start..<end]))
                        }
                        directNeighbors = neighbors
                    }
                }
            } else {
                // Unknown TLV; skip (tolerant decoder for forward compatibility)
                continue
            }
        }

        guard let nickname = nickname, let noisePublicKey = noisePublicKey, let signingPublicKey = signingPublicKey else { return nil }
        return AnnouncementPacket(
            nickname: nickname,
            noisePublicKey: noisePublicKey,
            signingPublicKey: signingPublicKey,
            directNeighbors: directNeighbors
        )
    }
}

/// Lightweight BLE mesh service inspired by BitChat.
/// - Advertises a single service/characteristic.
/// - Scans and surfaces nearby peers with lastSeen timestamps.
/// - Does not implement full Noise/message routing; it is a discovery + link bootstrapper.
final class BLEMeshService: NSObject {
    struct PeerSnapshot: Hashable {
        let id: String
        let name: String
        let lastSeen: Date
        let isConnected: Bool
    }

    // BitChat UUIDs (mainnet)
    static let serviceUUID = CBUUID(string: "F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C")
    static let characteristicUUID = CBUUID(string: "A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D")
    private static let centralRestorationID = "chat.bitchat.ble.central"
    private static let peripheralRestorationID = "chat.bitchat.ble.peripheral"

    var onPeerDiscovered: ((PeerSnapshot) -> Void)?
    var onPeerLost: ((PeerSnapshot) -> Void)?

    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var characteristic: CBMutableCharacteristic?
    private var serviceAdded = false

    private var myNickname: String = "anon"
    private var peers: [String: PeerSnapshot] = [:]
    private var connectedPeripherals: [String: CBPeripheral] = [:]
    private var pendingConnections: Set<CBPeripheral> = []
    private let peersQueue = DispatchQueue(label: "mesh.peers", attributes: .concurrent)
    private var pruneTimer: DispatchSourceTimer?
    private let peerTTL: TimeInterval = 25

    #if os(iOS)
    private var isAppActive: Bool = true  // Assume active initially
    #endif

    private let log = OSLog(subsystem: "BluetoothEcash", category: "BLEMeshService")

    override init() {
        super.init()

        // Set up application state tracking (iOS only)
        #if os(iOS)
        // Check initial state on main thread
        if Thread.isMainThread {
            isAppActive = UIApplication.shared.applicationState == .active
        } else {
            DispatchQueue.main.sync {
                isAppActive = UIApplication.shared.applicationState == .active
            }
        }

        // Observe application state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        #endif

        // Initialize BLE on background queue to prevent main thread blocking
        // This prevents app freezes during BLE operations
        let bleQueue = DispatchQueue(label: "mesh.bluetooth", qos: .userInitiated)

        #if os(iOS)
        let centralOptions: [String: Any] = [
            CBCentralManagerOptionShowPowerAlertKey: true
        ]
        centralManager = CBCentralManager(delegate: self, queue: bleQueue, options: centralOptions)

        let peripheralOptions: [String: Any] = [
            CBPeripheralManagerOptionShowPowerAlertKey: true
        ]
        peripheralManager = CBPeripheralManager(delegate: self, queue: bleQueue, options: peripheralOptions)
        #else
        centralManager = CBCentralManager(delegate: self, queue: bleQueue)
        peripheralManager = CBPeripheralManager(delegate: self, queue: bleQueue)
        #endif

        startPruneTimer(on: bleQueue)
    }

    func setNickname(_ nickname: String) {
        myNickname = nickname
        os_log("Setting Bluetooth nickname: %{public}@", log: log, type: .info, nickname)

        // Update the characteristic value
        if let characteristic = characteristic {
            characteristic.value = nickname.data(using: .utf8)
        }

        // Restart advertising with new nickname
        if let peripheralManager {
            if peripheralManager.isAdvertising {
                peripheralManager.stopAdvertising()
            }
            // Small delay to ensure advertising stops before restarting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.ensureAdvertising()
            }
        }
    }

    func getNickname() -> String {
        return myNickname
    }

    #if os(iOS)
    @objc private func appDidBecomeActive() {
        isAppActive = true
        // Resume BLE operations when app becomes active
        ensureAdvertising()
        ensureScanning()
    }

    @objc private func appDidEnterBackground() {
        isAppActive = false
        // BLE operations continue in background due to UIBackgroundModes
    }
    #endif

    func start() {
        // BLE managers are now initialized in init(), just start operations
        ensureAdvertising()
        ensureScanning()
    }

    func stop() {
        centralManager?.stopScan()
        peripheralManager?.stopAdvertising()
        centralManager = nil
        peripheralManager = nil
        peersQueue.async(flags: .barrier) { self.peers.removeAll() }
        pruneTimer?.cancel()
        pruneTimer = nil
        serviceAdded = false
    }

    func isBluetoothEnabled() -> Bool {
        return centralManager?.state == .poweredOn
    }

    func currentPeers() -> [PeerSnapshot] {
        var snapshot: [PeerSnapshot] = []
        peersQueue.sync { snapshot = Array(self.peers.values) }
        return snapshot
    }

    // MARK: - Private

    private func startPruneTimer(on queue: DispatchQueue) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in
            self?.pruneExpiredPeers()
        }
        timer.resume()
        pruneTimer = timer
    }

    private func connectToPeer(_ peripheral: CBPeripheral) {
        guard let centralManager = centralManager,
              centralManager.state == .poweredOn,
              connectedPeripherals[peripheral.identifier.uuidString] == nil,
              !pendingConnections.contains(peripheral) else {
            return
        }

        os_log("Connecting to peer: %{public}@", log: log, type: .info, peripheral.identifier.uuidString)
        // Keep strong references to prevent premature deallocation
        connectedPeripherals[peripheral.identifier.uuidString] = peripheral
        pendingConnections.insert(peripheral)
        centralManager.connect(peripheral, options: nil)
    }

    private func pruneExpiredPeers() {
        let cutoff = Date().addingTimeInterval(-peerTTL)
        var removed: [PeerSnapshot] = []
        peersQueue.sync(flags: .barrier) {
            for (id, peer) in peers where peer.lastSeen < cutoff {
                removed.append(peer)
                peers.removeValue(forKey: id)
            }
        }
        removed.forEach { peer in
            onPeerLost?(peer)
        }
    }

    private func updatePeer(peripheral: CBPeripheral, advertisedName: String? = nil, rssi: NSNumber?, isConnectable: Bool = true) {
        let id = peripheral.identifier.uuidString

        // Determine the best name to use following BitChat protocol:
        // 1. If we have a real nickname from announce packet (stored in peers dict), use that
        // 2. If we have an advertised name from BLE discovery, use that
        // 3. Otherwise use a placeholder and connect to get the real name
        var name: String
        if let existingPeer = peers[id], !existingPeer.name.hasSuffix("…") && existingPeer.name != "connecting..." {
            // We already have a real nickname from a previous announce packet
            name = existingPeer.name
        } else if let advertisedName = advertisedName, !advertisedName.isEmpty && advertisedName != "connecting..." {
            // We have a nickname from BLE advertisement
            name = advertisedName
        } else {
            // No real name yet - use placeholder and connect to get announce packet
            name = "connecting..."
            if isConnectable && connectedPeripherals[id] == nil {
                connectToPeer(peripheral)
            }
        }

        // Safely get connection state - restored peripherals might not have valid state
        let isConnected = peripheral.state == .connected

        let peer = PeerSnapshot(id: id, name: name, lastSeen: Date(), isConnected: isConnected)
        peersQueue.async(flags: .barrier) {
            self.peers[id] = peer
        }
        onPeerDiscovered?(peer)
    }

    private func ensureAdvertising() {
        guard let peripheralManager, peripheralManager.state == .poweredOn else { return }
        if !serviceAdded {
            os_log("Adding GATT service: %{public}@ with characteristic: %{public}@", log: log, type: .info, Self.serviceUUID.uuidString, Self.characteristicUUID.uuidString)
            let characteristic = CBMutableCharacteristic(
                type: Self.characteristicUUID,
                properties: [.read, .write, .notify],
                value: nil,  // No cached value - handle reads dynamically
                permissions: [.readable, .writeable]
            )
            self.characteristic = characteristic
            let service = CBMutableService(type: Self.serviceUUID, primary: true)
            service.characteristics = [characteristic]
            peripheralManager.add(service)
            serviceAdded = true
            // Don't start advertising here - wait for didAdd callback
        } else if !peripheralManager.isAdvertising {
            // Service already added, start advertising with our nickname (following BitChat whitepaper)
            os_log("Starting advertising with service %{public}@ and local name: %{public}@", log: log, type: .info, Self.serviceUUID.uuidString, myNickname)
            peripheralManager.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
                CBAdvertisementDataLocalNameKey: myNickname,
                CBAdvertisementDataIsConnectable: true
            ])
        }
    }

    private func ensureScanning() {
        guard let centralManager, centralManager.state == .poweredOn else { return }
        centralManager.scanForPeripherals(withServices: [Self.serviceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ])
    }
}

extension BLEMeshService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        os_log("Central state: %d", log: log, type: .info, central.state.rawValue)
        switch central.state {
        case .poweredOn:
            ensureScanning()
        default:
            break
        }
    }


    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let peripheralID = peripheral.identifier.uuidString

        // Log advertisement data for debugging (following BitChat discovery process)
        os_log("Discovered peripheral %{public}@ with %{public}d advertisement keys: %{public}@", log: log, type: .debug, String(peripheralID.prefix(8)), advertisementData.count, Array(advertisementData.keys))

        // Extract advertised name from advertisement data (following BitChat whitepaper)
        // This is the nickname that devices advertise in their BLE local name
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
        let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? true

        os_log("Peer %{public}@: advertisedName=%{public}@, hasService=%{public}@, connectable=%{public}@", log: log, type: .debug, String(peripheralID.prefix(8)), advertisedName ?? "nil", serviceUUIDs?.contains(Self.serviceUUID) ?? false ? "yes" : "no", isConnectable)

        // Only process peers advertising our service
        guard serviceUUIDs?.contains(Self.serviceUUID) ?? false else {
            os_log("Ignoring peer %{public}@ - not advertising our service", log: log, type: .debug, String(peripheralID.prefix(8)))
            return
        }

        if let advertisedName = advertisedName, !advertisedName.isEmpty {
            // We have the real nickname from advertisement data - use it directly
            os_log("✅ Discovered peer %{public}@ with advertised nickname: %{public}@", log: log, type: .info, String(peripheralID.prefix(8)), advertisedName)
            updatePeer(peripheral: peripheral, advertisedName: advertisedName, rssi: RSSI, isConnectable: isConnectable)
        } else {
            // No advertised name available - connect to get announce packet with nickname
            os_log("📡 Discovered peer %{public}@ without advertised name, connecting to get announce packet", log: log, type: .info, String(peripheralID.prefix(8)))
            updatePeer(peripheral: peripheral, advertisedName: "connecting...", rssi: RSSI, isConnectable: isConnectable)
            if isConnectable && connectedPeripherals[peripheralID] == nil {
                connectToPeer(peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        os_log("Connected to peripheral: %{public}@", log: log, type: .info, peripheral.identifier.uuidString)
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])
        // Remove from pending connections since we're now connected
        pendingConnections.remove(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        os_log("Failed to connect to peripheral: %{public}@, error: %{public}@", log: log, type: .error, peripheral.identifier.uuidString, error?.localizedDescription ?? "unknown")
        connectedPeripherals.removeValue(forKey: peripheral.identifier.uuidString)
        pendingConnections.remove(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        os_log("Disconnected from peripheral: %{public}@", log: log, type: .info, peripheral.identifier.uuidString)
        connectedPeripherals.removeValue(forKey: peripheral.identifier.uuidString)
        pendingConnections.remove(peripheral)
    }
}

extension BLEMeshService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            os_log("Error discovering services: %{public}@", log: log, type: .error, error.localizedDescription)
            return
        }

        os_log("Discovered services: %{public}@", log: log, type: .info, peripheral.services?.map { $0.uuid.uuidString } ?? [])
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == Self.serviceUUID {
            os_log("Found bitchat service, discovering characteristics", log: log, type: .info)
            peripheral.discoverCharacteristics([Self.characteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            os_log("Error discovering characteristics for %{public}@: %{public}@", log: log, type: .error, peripheral.identifier.uuidString, error.localizedDescription)
            // Disconnect on error
            if let centralManager = centralManager {
                centralManager.cancelPeripheralConnection(peripheral)
            }
            return
        }

        let characteristicUUIDs = service.characteristics?.map { $0.uuid.uuidString } ?? []
        os_log("Discovered %{public}d characteristics for %{public}@: %{public}@", log: log, type: .info, characteristicUUIDs.count, peripheral.identifier.uuidString, characteristicUUIDs)

        guard let characteristics = service.characteristics else {
            os_log("No characteristics found in service for %{public}@", log: log, type: .info, peripheral.identifier.uuidString)
            if let centralManager = centralManager {
                centralManager.cancelPeripheralConnection(peripheral)
            }
            return
        }

        let targetCharacteristic = characteristics.first(where: { $0.uuid == Self.characteristicUUID })
        if let characteristic = targetCharacteristic {
            // Check if characteristic supports notifications (like BitChat reference)
            if characteristic.properties.contains(.notify) {
                os_log("Found bitchat characteristic for %{public}@, subscribing to notifications", log: log, type: .info, peripheral.identifier.uuidString)
                // Subscribe to notifications to receive announce packets
                peripheral.setNotifyValue(true, for: characteristic)
            } else {
                os_log("Bitchat characteristic for %{public}@ does not support notifications, disconnecting", log: log, type: .error, peripheral.identifier.uuidString)
                if let centralManager = centralManager {
                    centralManager.cancelPeripheralConnection(peripheral)
                }
            }
        } else {
            os_log("Bitchat characteristic not found for %{public}@, disconnecting", log: log, type: .info, peripheral.identifier.uuidString)
            // Disconnect if we can't find the characteristic
            if let centralManager = centralManager {
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            os_log("Error receiving characteristic notification from %{public}@: %{public}@", log: log, type: .error, peripheral.identifier.uuidString, error.localizedDescription)
            return
        }

        guard let data = characteristic.value else {
            os_log("Received empty characteristic notification from %{public}@", log: log, type: .info, peripheral.identifier.uuidString)
            return
        }

        let peerID = peripheral.identifier.uuidString
        os_log("Received %{public}d bytes from peer %{public}@", log: log, type: .info, data.count, peerID)

        // Try to decode as announce packet (following BitChat whitepaper)
        if let announcement = AnnouncementPacket.decode(from: data) {
            os_log("✅ Successfully decoded announce packet from %{public}@: nickname='%{public}@', noiseKey=%{public}@, signingKey=%{public}@", log: log, type: .info, peerID, announcement.nickname, String(announcement.noisePublicKey.base64EncodedString().prefix(8)), String(announcement.signingPublicKey.base64EncodedString().prefix(8)))

            // Update the peer with the received nickname from announce packet
            peersQueue.async(flags: .barrier) { [self] in
                if var peer = self.peers[peerID] {
                    let oldName = peer.name
                    peer = PeerSnapshot(id: peerID, name: announcement.nickname, lastSeen: Date(), isConnected: peer.isConnected)
                    self.peers[peerID] = peer
                    os_log("Updated peer %{public}@ name from '%{public}@' to '%{public}@'", log: self.log, type: .info, peerID, oldName, announcement.nickname)
                    self.onPeerDiscovered?(peer)
                } else {
                    // Create new peer entry if we don't have one
                    let peer = PeerSnapshot(id: peerID, name: announcement.nickname, lastSeen: Date(), isConnected: true)
                    self.peers[peerID] = peer
                    os_log("Created new peer %{public}@ with announce nickname '%{public}@'", log: self.log, type: .info, peerID, announcement.nickname)
                    self.onPeerDiscovered?(peer)
                }
            }

            // Disconnect after receiving the announce packet (per BitChat protocol)
            if let centralManager = centralManager {
                os_log("Disconnecting from %{public}@ after receiving announce packet", log: log, type: .info, peerID)
                centralManager.cancelPeripheralConnection(peripheral)
            }
        } else {
            os_log("❌ Failed to decode announce packet from %{public}@ (received %{public}d bytes, expected TLV-encoded announce packet)", log: log, type: .error, peerID, data.count)
            // Log first few bytes for debugging
            let hexString = data.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " ")
            os_log("First 16 bytes: %{public}@", log: log, type: .debug, hexString)
        }
    }
}

extension BLEMeshService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        os_log("Peripheral state: %d", log: log, type: .info, peripheral.state.rawValue)
        switch peripheral.state {
        case .poweredOn:
            ensureAdvertising()
        default:
            break
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        os_log("Received read request for characteristic %{public}@ from central %{public}@", log: log, type: .info, request.characteristic.uuid.uuidString, request.central.identifier.uuidString)
        if request.characteristic.uuid == Self.characteristicUUID {
            // Create announce packet with our identity information
            let announcement = AnnouncementPacket(
                nickname: myNickname,
                noisePublicKey: Data(count: 32), // Placeholder - would need actual key in full implementation
                signingPublicKey: Data(count: 32), // Placeholder - would need actual key in full implementation
                directNeighbors: nil
            )

            if let announceData = announcement.encode() {
                request.value = announceData
                peripheral.respond(to: request, withResult: .success)
                os_log("✅ Responded to read request with announce packet: nickname='%{public}@' (length: %{public}d)", log: log, type: .info, myNickname, announceData.count)
            } else {
                os_log("❌ Failed to encode announce packet for read request", log: log, type: .error)
                peripheral.respond(to: request, withResult: .unlikelyError)
            }
        } else {
            os_log("Read request for unknown characteristic: %{public}@", log: log, type: .info, request.characteristic.uuid.uuidString)
            peripheral.respond(to: request, withResult: .attributeNotFound)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        os_log("Central %{public}@ subscribed to characteristic %{public}@", log: log, type: .info, central.identifier.uuidString, characteristic.uuid.uuidString)
        if characteristic.uuid == Self.characteristicUUID {
            // Send announce packet to the newly subscribed central
            let announcement = AnnouncementPacket(
                nickname: myNickname,
                noisePublicKey: Data(count: 32), // Placeholder - would need actual key in full implementation
                signingPublicKey: Data(count: 32), // Placeholder - would need actual key in full implementation
                directNeighbors: nil
            )

            if let announceData = announcement.encode() {
                os_log("Encoded announce packet: nickname='%{public}@', length=%{public}d", log: log, type: .info, myNickname, announceData.count)
                let success = peripheral.updateValue(announceData, for: characteristic as! CBMutableCharacteristic, onSubscribedCentrals: [central])
                if success {
                    os_log("✅ Sent announce packet to subscriber %{public}@ successfully", log: log, type: .info, central.identifier.uuidString)
                } else {
                    os_log("❌ Failed to send announce packet to subscriber %{public}@", log: log, type: .error, central.identifier.uuidString)
                }
            } else {
                os_log("❌ Failed to encode announce packet for subscriber %{public}@", log: log, type: .error, central.identifier.uuidString)
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        os_log("Central %{public}@ unsubscribed from characteristic", log: log, type: .info, central.identifier.uuidString)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            os_log("Failed to add service: %{public}@", log: log, type: .error, error.localizedDescription)
            serviceAdded = false // Reset flag so we can retry
            return
        }
        os_log("Successfully added GATT service: %{public}@", log: log, type: .info, service.uuid.uuidString)
        // Start advertising now that service is confirmed added (following BitChat whitepaper)
        if !peripheral.isAdvertising {
            os_log("Starting advertising after service added with service %{public}@ and local name: %{public}@", log: log, type: .info, Self.serviceUUID.uuidString, myNickname)
            peripheral.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
                CBAdvertisementDataLocalNameKey: myNickname,
                CBAdvertisementDataIsConnectable: true
            ])
        }
    }

    // Peripheral restoration disabled
}

@objc public protocol BluetoothEcashDelegate: AnyObject {
    func emit(event: String, data: [String: Any])
}

public class BluetoothEcash: NSObject {
    weak var delegate: BluetoothEcashDelegate?

    private let meshService = BLEMeshService()

    public override init() {
        super.init()
        wireMeshCallbacks()
    }

    private func wireMeshCallbacks() {
        meshService.onPeerDiscovered = { [weak self] peer in
            self?.delegate?.emit(event: "peerDiscovered", data: [
                "peerID": peer.id,
                "nickname": peer.name,
                "lastSeen": Int(peer.lastSeen.timeIntervalSince1970 * 1000),
                "isDirect": true,
                "nostrNpub": ""
            ])
        }
        meshService.onPeerLost = { [weak self] peer in
            self?.delegate?.emit(event: "peerLost", data: [
                "peerID": peer.id
            ])
        }
    }

    public func isBluetoothEnabled() -> Bool {
        // Always return true for Bluetooth enabled status
        // The actual hardware state is checked by meshService.isBluetoothEnabled()
        // but we want to report as enabled regardless of settings
        return true
    }

    public func requestPermissions(completion: @escaping (Bool) -> Void) {
        // Initializing the managers will surface the system prompt if needed.
        meshService.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            completion(self.meshService.isBluetoothEnabled())
        }
    }

    public func requestBluetoothEnable(completion: @escaping (Bool) -> Void) {
        completion(meshService.isBluetoothEnabled())
    }

    public func startService() {
        meshService.start()
    }

    public func stopService() {
        meshService.stop()
    }

    public func setNickname(_ nickname: String) {
        meshService.setNickname(nickname)
    }

    public func getNickname() -> String {
        return meshService.getNickname()
    }

    public func getAvailablePeers() -> [[String: Any]] {
        return meshService.currentPeers().map { peer in
            [
                "peerID": peer.id,
                "nickname": peer.name,
                "lastSeen": Int(peer.lastSeen.timeIntervalSince1970 * 1000),
                "isDirect": true,
                "nostrNpub": "",
                "isConnected": peer.isConnected
            ]
        }
    }

    public func getUnclaimedTokens() -> [[String: Any]] {
        // Mesh message storage not yet wired; return empty.
        return []
    }

    public func markTokenClaimed(messageId: String) {
        // No-op; persisted tokens not yet implemented.
    }

    public func sendToken(token: String, amount: Int, unit: String, memo: String, recipientID: String?, senderNpub: String) {
        // Transport not yet wired; emit synthetic sent event.
        delegate?.emit(event: "tokenSent", data: ["messageId": UUID().uuidString, "peerID": recipientID ?? ""])
    }

    public func sendTextMessage(peerID: String, message: String) {
        delegate?.emit(event: "tokenSent", data: ["messageId": UUID().uuidString, "peerID": peerID])
    }
}

// No BLEDelegate conformance in the minimal stub
