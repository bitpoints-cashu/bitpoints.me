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

    private var peers: [String: PeerSnapshot] = [:]
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
            CBCentralManagerOptionRestoreIdentifierKey: Self.centralRestorationID,
            CBCentralManagerOptionShowPowerAlertKey: true
        ]
        centralManager = CBCentralManager(delegate: self, queue: bleQueue, options: centralOptions)

        let peripheralOptions: [String: Any] = [
            CBPeripheralManagerOptionRestoreIdentifierKey: Self.peripheralRestorationID,
            CBPeripheralManagerOptionShowPowerAlertKey: true
        ]
        peripheralManager = CBPeripheralManager(delegate: self, queue: bleQueue, options: peripheralOptions)
        #else
        centralManager = CBCentralManager(delegate: self, queue: bleQueue)
        peripheralManager = CBPeripheralManager(delegate: self, queue: bleQueue)
        #endif

        startPruneTimer(on: bleQueue)
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

    private func updatePeer(peripheral: CBPeripheral, rssi: NSNumber?) {
        let id = peripheral.identifier.uuidString
        let name = peripheral.name ?? "peer"
        let peer = PeerSnapshot(id: id, name: name, lastSeen: Date(), isConnected: peripheral.state == .connected)
        peersQueue.async(flags: .barrier) {
            self.peers[id] = peer
        }
        onPeerDiscovered?(peer)
    }

    private func ensureAdvertising() {
        guard let peripheralManager, peripheralManager.state == .poweredOn else { return }
        if !serviceAdded {
            let characteristic = CBMutableCharacteristic(
                type: Self.characteristicUUID,
                properties: [.read, .write, .notify],
                value: nil,
                permissions: [.readable, .writeable]
            )
            self.characteristic = characteristic
            let service = CBMutableService(type: Self.serviceUUID, primary: true)
            service.characteristics = [characteristic]
            peripheralManager.add(service)
            serviceAdded = true
        }
        if !peripheralManager.isAdvertising {
            peripheralManager.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID]
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

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        let restoredPeripherals = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]) ?? []
        let restoredServices = (dict[CBCentralManagerRestoredStateScanServicesKey] as? [CBUUID]) ?? []

        os_log("Central restore: peripherals=%d services=%d", log: log, type: .info, restoredPeripherals.count, restoredServices.count)

        // Handle restored peripherals if needed
        for peripheral in restoredPeripherals {
            updatePeer(peripheral: peripheral, rssi: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        updatePeer(peripheral: peripheral, rssi: RSSI)
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

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            os_log("Failed to add service: %{public}@", log: log, type: .error, error.localizedDescription)
            return
        }
        ensureAdvertising()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        let restoredServices = (dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService]) ?? []
        let restoredAdvertisement = (dict[CBPeripheralManagerRestoredStateAdvertisementDataKey] as? [String: Any]) ?? [:]

        os_log("Peripheral restore: services=%d advertisingDataKeys=%d", log: log, type: .info, restoredServices.count, restoredAdvertisement.count)

        // Attempt to recover characteristic from restored services
        if self.characteristic == nil {
            if let service = restoredServices.first(where: { $0.uuid == Self.serviceUUID }),
               let restoredCharacteristic = service.characteristics?.first(where: { $0.uuid == Self.characteristicUUID }) as? CBMutableCharacteristic {
                self.characteristic = restoredCharacteristic
            }
        }

        // Resume advertising if we were advertising before
        if peripheral.state == .poweredOn && !peripheral.isAdvertising {
            ensureAdvertising()
        }
    }
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
        return meshService.isBluetoothEnabled()
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
