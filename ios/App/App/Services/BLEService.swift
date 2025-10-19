//
// BLEService.swift
// bitpoints.me
//
// Simplified Bluetooth Low Energy service for cross-platform compatibility
//

import Foundation
import CoreBluetooth
import CryptoKit

/// BLEService — Bluetooth Mesh Transport
/// Simplified version for bitpoints.me ecash functionality
final class BLEService: NSObject {

    // MARK: - Constants

    #if DEBUG
    static let serviceUUID = CBUUID(string: "F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5A") // testnet
    #else
    static let serviceUUID = CBUUID(string: "F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C") // mainnet
    #endif
    static let characteristicUUID = CBUUID(string: "A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D")

    // Default per-fragment chunk size when link limits are unknown
    private let defaultFragmentSize = TransportConfig.bleDefaultFragmentSize
    private let messageTTL: UInt8 = TransportConfig.messageTTLDefault

    // MARK: - Core State

    // Peripheral Tracking
    private struct PeripheralState {
        let peripheral: CBPeripheral
        var characteristic: CBCharacteristic?
        var peerID: PeerID?
        var isConnecting: Bool = false
        var isConnected: Bool = false
        var lastConnectionAttempt: Date? = nil
    }
    private var peripherals: [String: PeripheralState] = [:]
    private var peerToPeripheralUUID: [PeerID: String] = [:]

    // BLE Centrals (when acting as peripheral)
    private var subscribedCentrals: [CBCentral] = []
    private var centralToPeerID: [String: PeerID] = [:]

    // Peer Information
    private struct PeerInfo {
        let peerID: PeerID
        var nickname: String
        var isConnected: Bool
        var noisePublicKey: Data?
        var signingPublicKey: Data?
        var lastSeen: Date
    }
    private var peers: [PeerID: PeerInfo] = [:]

    // Fragment Reassembly
    private struct FragmentKey: Hashable {
        let sender: UInt64
        let id: UInt64
    }
    private var incomingFragments: [FragmentKey: [Int: Data]] = [:]
    private var fragmentMetadata: [FragmentKey: (type: UInt8, total: Int, timestamp: Date)] = [:]

    // MARK: - Core BLE Objects

    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var characteristic: CBMutableCharacteristic?

    // MARK: - Identity

    private var noiseService: NoiseEncryptionService
    private let keychain: KeychainManagerProtocol
    private var myPeerIDData: Data = Data()

    // MARK: - Queues

    private let messageQueue = DispatchQueue(label: "me.bitpoints.wallet.mesh.message", attributes: .concurrent)
    private let collectionsQueue = DispatchQueue(label: "me.bitpoints.wallet.mesh.collections", attributes: .concurrent)
    private let bleQueue = DispatchQueue(label: "me.bitpoints.wallet.mesh.bluetooth", qos: .userInitiated)

    // MARK: - Delegate

    weak var delegate: BLEServiceDelegate?

    // MARK: - Initialization

    init(noiseService: NoiseEncryptionService, keychain: KeychainManagerProtocol) {
        self.noiseService = noiseService
        self.keychain = keychain
        super.init()

        // Initialize peer ID
        let peerID = PeerID(publicKey: noiseService.getStaticPublicKeyData())
        myPeerIDData = peerID.id.data(using: .utf8) ?? Data()

        print("BLEService: Initialized with peer ID: \(peerID)")
    }

    // MARK: - Service Control

    func startService() {
        print("BLEService: Starting service")

        // Start central manager for scanning
        centralManager = CBCentralManager(delegate: self, queue: bleQueue)

        // Start peripheral manager for advertising
        peripheralManager = CBPeripheralManager(delegate: self, queue: bleQueue)
    }

    func stopService() {
        print("BLEService: Stopping service")

        // Stop scanning
        centralManager?.stopScan()

        // Disconnect all peripherals
        for peripheral in peripherals.values {
            centralManager?.cancelPeripheralConnection(peripheral.peripheral)
        }

        // Stop advertising
        peripheralManager?.stopAdvertising()

        // Clear state
        peripherals.removeAll()
        peers.removeAll()
        subscribedCentrals.removeAll()
    }

    // MARK: - Message Sending

    func sendMessage(_ message: Data, to peerID: PeerID) {
        print("BLEService: Sending message to \(peerID)")

        // Create packet
        let packet = BitchatPacket(
            type: 0xE1, // Ecash message type
            ttl: messageTTL,
            senderID: PeerID(publicKey: noiseService.getStaticPublicKeyData()),
            payload: message
        )

        // Try to encrypt if we have a session
        if noiseService.hasEstablishedSession(with: peerID) {
            do {
                let encryptedPayload = try noiseService.encrypt(message, for: peerID)
                let encryptedPacket = BitchatPacket(
                    type: 0xE1,
                    ttl: messageTTL,
                    senderID: PeerID(publicKey: noiseService.getStaticPublicKeyData()),
                    payload: encryptedPayload
                )
                sendPacket(encryptedPacket, to: peerID)
            } catch {
                print("BLEService: Failed to encrypt message: \(error)")
                sendPacket(packet, to: peerID)
            }
        } else {
            // Send unencrypted
            sendPacket(packet, to: peerID)
        }
    }

    private func sendPacket(_ packet: BitchatPacket, to peerID: PeerID) {
        guard let packetData = packet.toBinaryData(padding: false) else {
            print("BLEService: Failed to encode packet")
            return
        }

        // Fragment if necessary
        if packetData.count <= defaultFragmentSize {
            sendFragment(packetData, to: peerID)
        } else {
            fragmentAndSend(packetData, to: peerID)
        }
    }

    private func sendFragment(_ data: Data, to peerID: PeerID) {
        // Find peripheral for this peer
        guard let peripheralUUID = peerToPeripheralUUID[peerID],
              let peripheralState = peripherals[peripheralUUID],
              let characteristic = peripheralState.characteristic else {
            print("BLEService: No connection to peer \(peerID)")
            return
        }

        // Write to characteristic
        peripheralState.peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("BLEService: Sent fragment to \(peerID)")
    }

    private func fragmentAndSend(_ data: Data, to peerID: PeerID) {
        // Simple fragmentation - split into chunks
        let chunkSize = defaultFragmentSize
        let totalChunks = (data.count + chunkSize - 1) / chunkSize

        for i in 0..<totalChunks {
            let start = i * chunkSize
            let end = min(start + chunkSize, data.count)
            let chunk = data.subdata(in: start..<end)

            // Add fragment header (simplified)
            var fragmentData = Data()
            fragmentData.append(UInt8(i)) // Fragment index
            fragmentData.append(UInt8(totalChunks)) // Total fragments
            fragmentData.append(chunk)

            sendFragment(fragmentData, to: peerID)
        }
    }

    // MARK: - Message Processing

    private func processIncomingMessage(_ data: Data, from peerID: PeerID) {
        print("BLEService: Processing message from \(peerID)")

        // Check if this is a fragment
        if data.count >= 2 {
            let fragmentIndex = data[0]
            let totalFragments = data[1]

            if totalFragments > 1 {
                // This is a fragment
                processFragment(data, from: peerID, index: Int(fragmentIndex), total: Int(totalFragments))
                return
            }
        }

        // Process complete message
        processCompleteMessage(data, from: peerID)
    }

    private func processFragment(_ data: Data, from peerID: PeerID, index: Int, total: Int) {
        let fragmentKey = FragmentKey(sender: UInt64(peerID.id.hashValue), id: UInt64(index))
        let fragmentData = data.dropFirst(2) // Remove header

        // Store fragment
        incomingFragments[fragmentKey, default: [:]][index] = fragmentData

        // Check if we have all fragments
        if incomingFragments[fragmentKey]?.count == total {
            // Reassemble message
            var completeData = Data()
            for i in 0..<total {
                if let fragment = incomingFragments[fragmentKey]?[i] {
                    completeData.append(fragment)
                }
            }

            // Clean up fragments
            incomingFragments.removeValue(forKey: fragmentKey)

            // Process complete message
            processCompleteMessage(completeData, from: peerID)
        }
    }

    private func processCompleteMessage(_ data: Data, from peerID: PeerID) {
        // Try to decode as BitchatPacket
        if let packet = BitchatPacket.from(data) {
            // Try to decrypt if we have a session
            if noiseService.hasEstablishedSession(with: peerID) {
                do {
                    let decryptedPayload = try noiseService.decrypt(packet.payload, from: peerID)
                    delegate?.didReceiveMessage(decryptedPayload, from: peerID)
                } catch {
                    print("BLEService: Failed to decrypt message: \(error)")
                    delegate?.didReceiveMessage(packet.payload, from: peerID)
                }
            } else {
                // Process unencrypted
                delegate?.didReceiveMessage(packet.payload, from: peerID)
            }
        } else {
            // Process as raw data
            delegate?.didReceiveMessage(data, from: peerID)
        }
    }

    // MARK: - Peer Management

    func getActivePeers() -> [PeerInfo] {
        return Array(peers.values)
    }

    func getPeerInfo(for peerID: PeerID) -> PeerInfo? {
        return peers[peerID]
    }

    private func addPeer(_ peerID: PeerID, nickname: String = "Unknown") {
        let peerInfo = PeerInfo(
            peerID: peerID,
            nickname: nickname,
            isConnected: false,
            noisePublicKey: nil,
            signingPublicKey: nil,
            lastSeen: Date()
        )
        peers[peerID] = peerInfo
        delegate?.didDiscoverPeer(peerID)
    }

    private func updatePeerConnection(_ peerID: PeerID, isConnected: Bool) {
        if var peerInfo = peers[peerID] {
            peerInfo.isConnected = isConnected
            peerInfo.lastSeen = Date()
            peers[peerID] = peerInfo
            delegate?.didUpdatePeerConnection(peerID, isConnected: isConnected)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("BLEService: Central manager state: \(central.state.rawValue)")

        switch central.state {
        case .poweredOn:
            // Start scanning
            centralManager?.scanForPeripherals(withServices: [BLEService.serviceUUID], options: nil)
            print("BLEService: Started scanning for peripherals")
        case .poweredOff, .unauthorized, .unsupported:
            print("BLEService: Bluetooth not available")
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("BLEService: Discovered peripheral: \(peripheral.identifier)")

        // Connect to peripheral
        centralManager?.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("BLEService: Connected to peripheral: \(peripheral.identifier)")

        // Discover services
        peripheral.delegate = self
        peripheral.discoverServices([BLEService.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("BLEService: Failed to connect to peripheral: \(peripheral.identifier), error: \(error?.localizedDescription ?? "Unknown")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("BLEService: Disconnected from peripheral: \(peripheral.identifier)")

        // Update peer connection status
        if let peerID = peripherals[peripheral.identifier.uuidString]?.peerID {
            updatePeerConnection(peerID, isConnected: false)
        }

        // Remove peripheral
        peripherals.removeValue(forKey: peripheral.identifier.uuidString)
    }
}

// MARK: - CBPeripheralDelegate

extension BLEService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            if service.uuid == BLEService.serviceUUID {
                peripheral.discoverCharacteristics([BLEService.characteristicUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.uuid == BLEService.characteristicUUID {
                // Subscribe to notifications
                peripheral.setNotifyValue(true, for: characteristic)

                // Update peripheral state
                if var state = peripherals[peripheral.identifier.uuidString] {
                    state.characteristic = characteristic
                    state.isConnected = true
                    peripherals[peripheral.identifier.uuidString] = state

                    // Create peer ID (simplified)
                    let peerID = PeerID(publicKey: Data(repeating: 0, count: 32)) // Placeholder
                    state.peerID = peerID
                    peerToPeripheralUUID[peerID] = peripheral.identifier.uuidString
                    peripherals[peripheral.identifier.uuidString] = state

                    addPeer(peerID)
                    updatePeerConnection(peerID, isConnected: true)
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        if let peerID = peripherals[peripheral.identifier.uuidString]?.peerID {
            processIncomingMessage(data, from: peerID)
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLEService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("BLEService: Peripheral manager state: \(peripheral.state.rawValue)")

        switch peripheral.state {
        case .poweredOn:
            // Create service and characteristic
            let service = CBMutableService(type: BLEService.serviceUUID, primary: true)
            characteristic = CBMutableCharacteristic(
                type: BLEService.characteristicUUID,
                properties: [.read, .write, .notify],
                value: nil,
                permissions: [.readable, .writeable]
            )
            service.characteristics = [characteristic!]

            // Add service
            peripheralManager?.add(service)

            // Start advertising
            let advertisementData: [String: Any] = [
                CBAdvertisementDataServiceUUIDsKey: [BLEService.serviceUUID]
            ]
            peripheralManager?.startAdvertising(advertisementData)
            print("BLEService: Started advertising")
        case .poweredOff, .unauthorized, .unsupported:
            print("BLEService: Bluetooth not available for advertising")
        default:
            break
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("BLEService: Failed to add service: \(error)")
        } else {
            print("BLEService: Added service successfully")
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("BLEService: Failed to start advertising: \(error)")
        } else {
            print("BLEService: Started advertising successfully")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("BLEService: Central subscribed to characteristic: \(central.identifier)")
        subscribedCentrals.append(central)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("BLEService: Central unsubscribed from characteristic: \(central.identifier)")
        subscribedCentrals.removeAll { $0.identifier == central.identifier }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        // Handle read requests
        request.value = myPeerIDData
        peripheralManager?.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        // Handle write requests
        for request in requests {
            if let data = request.value {
                // Process incoming data
                let peerID = PeerID(publicKey: Data(repeating: 0, count: 32)) // Placeholder
                processIncomingMessage(data, from: peerID)
            }
            peripheralManager?.respond(to: request, withResult: .success)
        }
    }
}

// MARK: - BLEServiceDelegate

protocol BLEServiceDelegate: AnyObject {
    func didDiscoverPeer(_ peerID: PeerID)
    func didUpdatePeerConnection(_ peerID: PeerID, isConnected: Bool)
    func didReceiveMessage(_ data: Data, from peerID: PeerID)
}
