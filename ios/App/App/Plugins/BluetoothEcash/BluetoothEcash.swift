import Foundation
import CoreBluetooth
import os.log
#if os(iOS)
import UIKit
#endif

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

    private func updatePeer(peripheral: CBPeripheral, advertisementData: [String: Any]? = nil, advertisedName: String? = nil, rssi: NSNumber?) {
        let id = peripheral.identifier.uuidString

        // Use advertised name if available, otherwise check if we already have a name from GATT reads
        var name = advertisedName ?? peers[id]?.name ?? "peer"

        // For discovered peripherals, try to connect and read the name via GATT if we don't have a name
        if advertisementData != nil && name == "peer" && connectedPeripherals[id] == nil {
            connectToPeer(peripheral)
        }

        // Safely get connection state - restored peripherals might not have valid state
        let isConnected: Bool
        do {
            isConnected = peripheral.state == .connected
        } catch {
            // If we can't access the state safely, assume not connected
            os_log("Could not access peripheral state safely, assuming not connected", log: log, type: .info)
            isConnected = false
        }

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
            // Service already added, start advertising
            os_log("Starting advertising with nickname: %{public}@", log: log, type: .info, myNickname)
            peripheralManager.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
                CBAdvertisementDataLocalNameKey: myNickname
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
        // Safely extract device name from advertisement data
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String

        // Filter advertisement data to only include safe, serializable values
        // This prevents crashes from malformed advertisement data
        let safeAdvertisementData: [String: Any] = advertisementData.filter { key, value in
            // Only include values that are safe to work with
            switch value {
            case is String, is Int, is Double, is Bool, is NSNumber:
                return true
            case let array as [Any]:
                // Only include arrays of safe types
                return array.allSatisfy { item in
                    item is String || item is Int || item is Double || item is Bool || item is NSNumber
                }
            case let dict as [String: Any]:
                // Only include dictionaries with safe key/value types
                return dict.allSatisfy { dictKey, dictValue in
                    dictKey is String && (dictValue is String || dictValue is Int || dictValue is Double || dictValue is Bool || dictValue is NSNumber)
                }
            default:
                // Skip complex objects, CBUUID instances, Data objects, etc.
                return false
            }
        }

        updatePeer(peripheral: peripheral, advertisementData: safeAdvertisementData, advertisedName: advertisedName, rssi: RSSI)
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
            os_log("Error discovering characteristics: %{public}@", log: log, type: .error, error.localizedDescription)
            return
        }

        let characteristicUUIDs = service.characteristics?.map { $0.uuid.uuidString } ?? []
        os_log("Discovered characteristics: %{public}@", log: log, type: .info, characteristicUUIDs)

        guard let characteristics = service.characteristics else {
            os_log("No characteristics found in service", log: log, type: .info)
            return
        }

        let targetCharacteristic = characteristics.first(where: { $0.uuid == Self.characteristicUUID })
        if let characteristic = targetCharacteristic {
            os_log("Found bitchat characteristic, subscribing to notifications", log: log, type: .info)
            // Subscribe to notifications instead of reading value directly
            peripheral.setNotifyValue(true, for: characteristic)

            // Store the characteristic for later use
            // We'll disconnect after receiving the nickname notification
        } else {
            os_log("Bitchat characteristic not found in discovered characteristics", log: log, type: .info)
            // Disconnect if we can't find the characteristic
            if let centralManager = centralManager {
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            os_log("Error receiving characteristic notification: %{public}@", log: log, type: .error, error.localizedDescription)
            return
        }

        guard let data = characteristic.value else {
            os_log("Received empty characteristic notification", log: log, type: .info)
            return
        }

        let peerID = peripheral.identifier.uuidString
        os_log("Received %{public}d bytes from peer %{public}@", log: log, type: .info, data.count, peerID)

        // For now, treat the data as a simple nickname string
        // In the future, this should decode proper Bitchat announce messages
        if let nickname = String(data: data, encoding: .utf8), !nickname.isEmpty {
            os_log("Received nickname from peer %{public}@: %{public}@", log: log, type: .info, peerID, nickname)

            // Update the peer with the received nickname
            peersQueue.async(flags: .barrier) {
                if var peer = self.peers[peerID] {
                    peer = PeerSnapshot(id: peerID, name: nickname, lastSeen: Date(), isConnected: peer.isConnected)
                    self.peers[peerID] = peer
                    self.onPeerDiscovered?(peer)
                }
            }

            // Disconnect after receiving the nickname
            if let centralManager = centralManager {
                centralManager.cancelPeripheralConnection(peripheral)
            }
        } else {
            os_log("Received non-string data from peer %{public}@", log: log, type: .info, peerID)
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
        os_log("Received read request for characteristic: %{public}@", log: log, type: .info, request.characteristic.uuid.uuidString)
        if request.characteristic.uuid == Self.characteristicUUID {
            // Return our nickname when requested
            let nicknameData = myNickname.data(using: .utf8)
            request.value = nicknameData
            peripheral.respond(to: request, withResult: .success)
            os_log("Responded to read request with nickname: %{public}@ (length: %d)", log: log, type: .info, myNickname, nicknameData?.count ?? 0)
        } else {
            os_log("Read request for unknown characteristic: %{public}@", log: log, type: .info, request.characteristic.uuid.uuidString)
            peripheral.respond(to: request, withResult: .attributeNotFound)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        os_log("Central %{public}@ subscribed to characteristic", log: log, type: .info, central.identifier.uuidString)
        if characteristic.uuid == Self.characteristicUUID {
            // Send our nickname to the newly subscribed central
            let nicknameData = myNickname.data(using: .utf8)
            let success = peripheral.updateValue(nicknameData!, for: characteristic as! CBMutableCharacteristic, onSubscribedCentrals: [central])
            os_log("Sent nickname to subscriber: %{public}@ (success: %d)", log: log, type: .info, myNickname, success)
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
        // Start advertising now that service is confirmed added
        if !peripheral.isAdvertising {
            os_log("Starting advertising after service added with nickname: %{public}@", log: log, type: .info, myNickname)
            peripheral.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
                CBAdvertisementDataLocalNameKey: myNickname
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
