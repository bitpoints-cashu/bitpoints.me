import Foundation
import CoreBluetooth
import os.log

/// Complete Bluetooth Low Energy mesh transport service
/// Adapted from bitchat for bitpoints.me
class BLEService: NSObject {

    // MARK: - Properties

    private let logger = Logger(subsystem: "me.bitpoints.wallet", category: "BLEService")
    private let bleQueue = DispatchQueue(label: "ble.service.queue", qos: .userInitiated)

    // Core Bluetooth managers
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?

    // BLE state
    private var isScanning = false
    private var isAdvertising = false
    private var connectedPeripherals: Set<CBPeripheral> = []
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]

    // Services and characteristics
    private var meshService: CBMutableService?
    private var meshCharacteristic: CBMutableCharacteristic?

    // Configuration
    private let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let characteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")

    // Delegate
    weak var delegate: BLEServiceDelegate?

    // MARK: - Initialization

    override init() {
        super.init()
        logger.info("🔵 BLEService: Initializing")

        // Initialize BLE managers on background queue
        bleQueue.async { [weak self] in
            self?.initializeBLE()
        }
    }

    private func initializeBLE() {
        logger.info("🔵 BLEService: Initializing BLE managers")

        // Initialize central manager for scanning and connecting
        centralManager = CBCentralManager(
            delegate: self,
            queue: bleQueue,
            options: [
                CBCentralManagerOptionShowPowerAlertKey: true,
                CBCentralManagerOptionRestoreIdentifierKey: "bitpoints-central"
            ]
        )

        // Initialize peripheral manager for advertising
        peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: bleQueue,
            options: [
                CBPeripheralManagerOptionShowPowerAlertKey: true,
                CBPeripheralManagerOptionRestoreIdentifierKey: "bitpoints-peripheral"
            ]
        )

        logger.info("🔵 BLEService: BLE managers initialized")
    }

    // MARK: - Public Interface

    func startService() {
        logger.info("🔵 BLEService: Starting service")
        
        #if targetEnvironment(simulator)
        logger.warning("🔵 BLEService: Running on iOS Simulator - Bluetooth will not work")
        return
        #endif

        bleQueue.async { [weak self] in
            self?.startBLEOperations()
        }
    }

    func stopService() {
        logger.info("🔵 BLEService: Stopping service")

        bleQueue.async { [weak self] in
            self?.stopBLEOperations()
        }
    }

    func getCurrentBluetoothState() -> CBManagerState {
        return centralManager?.state ?? .unknown
    }

    // MARK: - Private Methods

    private func startBLEOperations() {
        guard let central = centralManager, let peripheral = peripheralManager else {
            logger.error("🔵 BLEService: BLE managers not initialized")
            return
        }

        // Start scanning if central manager is ready
        if central.state == .poweredOn {
            startScanning()
        } else {
            logger.warning("🔵 BLEService: Central manager not ready: \(central.state.debugDescription)")
        }
        
        // Start advertising if peripheral manager is ready
        if peripheral.state == .poweredOn {
            startAdvertising()
        } else {
            logger.warning("🔵 BLEService: Peripheral manager not ready: \(peripheral.state.debugDescription)")
        }
    }

    private func stopBLEOperations() {
        stopScanning()
        stopAdvertising()
        disconnectAllPeripherals()
    }

    private func startScanning() {
        guard let central = centralManager, central.state == .poweredOn, !isScanning else {
            return
        }

        logger.info("🔵 BLEService: Starting scan")

        // Scan for peripherals with our service
        central.scanForPeripherals(
            withServices: [serviceUUID],
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true
            ]
        )

        isScanning = true
        logger.info("🔵 BLEService: Scan started")
    }

    private func stopScanning() {
        guard let central = centralManager, isScanning else { return }

        logger.info("🔵 BLEService: Stopping scan")
        central.stopScan()
        isScanning = false
        logger.info("🔵 BLEService: Scan stopped")
    }
    
    private func startAdvertising() {
        guard let peripheral = peripheralManager, peripheral.state == .poweredOn, !isAdvertising else {
            return
        }

        logger.info("🔵 BLEService: Starting advertising")

        // Create mesh service
        meshService = CBMutableService(type: serviceUUID, primary: true)

        // Create mesh characteristic
        meshCharacteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        meshService?.characteristics = [meshCharacteristic!]
        
        // Add service
        peripheral.add(meshService!)
        
        // Start advertising
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "Bitpoints"
        ]

        peripheral.startAdvertising(advertisementData)
        isAdvertising = true

        logger.info("🔵 BLEService: Advertising started")
    }

    private func stopAdvertising() {
        guard let peripheral = peripheralManager, isAdvertising else { return }

        logger.info("🔵 BLEService: Stopping advertising")
        peripheral.stopAdvertising()
        isAdvertising = false

        if let service = meshService {
            peripheral.remove(service)
        }

        logger.info("🔵 BLEService: Advertising stopped")
    }

    private func disconnectAllPeripherals() {
        logger.info("🔵 BLEService: Disconnecting all peripherals")

        for peripheral in connectedPeripherals {
            if peripheral.state == .connected {
                centralManager?.cancelPeripheralConnection(peripheral)
            }
        }

        connectedPeripherals.removeAll()
        discoveredPeripherals.removeAll()

        logger.info("🔵 BLEService: All peripherals disconnected")
    }

    private func connectToPeripheral(_ peripheral: CBPeripheral) {
        guard let central = centralManager, central.state == .poweredOn else { return }

        logger.info("🔵 BLEService: Connecting to peripheral: \(peripheral.identifier)")

        // Store peripheral
        discoveredPeripherals[peripheral.identifier] = peripheral

        // Connect
        central.connect(peripheral, options: nil)
    }

    private func disconnectPeripheral(_ peripheral: CBPeripheral) {
        guard let central = centralManager else { return }

        logger.info("🔵 BLEService: Disconnecting peripheral: \(peripheral.identifier)")

        central.cancelPeripheralConnection(peripheral)
        connectedPeripherals.remove(peripheral)
        discoveredPeripherals.removeValue(forKey: peripheral.identifier)
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEService: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.info("🔵 BLEService: Central manager state changed to: \(central.state.debugDescription)")

        switch central.state {
        case .poweredOn:
            logger.info("🔵 BLEService: Bluetooth is powered on")
            startScanning()

        case .poweredOff:
            logger.warning("🔵 BLEService: Bluetooth is powered off")
            stopScanning()
            disconnectAllPeripherals()

        case .unauthorized:
            logger.error("🔵 BLEService: Bluetooth is unauthorized")

        case .unsupported:
            logger.error("🔵 BLEService: Bluetooth is unsupported")

        case .resetting:
            logger.warning("🔵 BLEService: Bluetooth is resetting")

        case .unknown:
            logger.warning("🔵 BLEService: Bluetooth state is unknown")

        @unknown default:
            logger.warning("🔵 BLEService: Bluetooth state is unknown (future)")
        }

        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.bleServiceDidUpdateState(central.state)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        logger.debug("🔵 BLEService: Discovered peripheral: \(peripheral.identifier), RSSI: \(RSSI)")

        // Connect to discovered peripheral
        connectToPeripheral(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("🔵 BLEService: Connected to peripheral: \(peripheral.identifier)")

        connectedPeripherals.insert(peripheral)
        peripheral.delegate = self

        // Discover services
        peripheral.discoverServices([serviceUUID])

        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.bleServiceDidConnectPeripheral(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("🔵 BLEService: Failed to connect to peripheral: \(peripheral.identifier), error: \(error?.localizedDescription ?? "unknown")")

        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.bleServiceDidFailToConnectPeripheral(peripheral, error: error)
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("🔵 BLEService: Disconnected from peripheral: \(peripheral.identifier), error: \(error?.localizedDescription ?? "none")")

        connectedPeripherals.remove(peripheral)

        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.bleServiceDidDisconnectPeripheral(peripheral, error: error)
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLEService: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        logger.info("🔵 BLEService: Peripheral manager state changed to: \(peripheral.state.debugDescription)")

        switch peripheral.state {
        case .poweredOn:
            logger.info("🔵 BLEService: Peripheral manager is powered on")
            startAdvertising()

        case .poweredOff:
            logger.warning("🔵 BLEService: Peripheral manager is powered off")
            stopAdvertising()

        case .unauthorized:
            logger.error("🔵 BLEService: Peripheral manager is unauthorized")

        case .unsupported:
            logger.error("🔵 BLEService: Peripheral manager is unsupported")

        case .resetting:
            logger.warning("🔵 BLEService: Peripheral manager is resetting")

        case .unknown:
            logger.warning("🔵 BLEService: Peripheral manager state is unknown")

        @unknown default:
            logger.warning("🔵 BLEService: Peripheral manager state is unknown (future)")
        }

        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.bleServiceDidUpdatePeripheralState(peripheral.state)
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            logger.error("🔵 BLEService: Failed to start advertising: \(error.localizedDescription)")
        } else {
            logger.info("🔵 BLEService: Successfully started advertising")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            logger.error("🔵 BLEService: Failed to add service: \(error.localizedDescription)")
        } else {
            logger.info("🔵 BLEService: Successfully added service: \(service.uuid)")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        logger.info("🔵 BLEService: Central subscribed to characteristic: \(characteristic.uuid)")

        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.bleServiceDidSubscribeToCharacteristic(characteristic, central: central)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        logger.info("🔵 BLEService: Central unsubscribed from characteristic: \(characteristic.uuid)")

        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.bleServiceDidUnsubscribeFromCharacteristic(characteristic, central: central)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        logger.debug("🔵 BLEService: Received read request for characteristic: \(request.characteristic.uuid)")

        // Respond with empty data for now
        request.value = Data()
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        logger.debug("🔵 BLEService: Received \(requests.count) write requests")

        for request in requests {
            logger.debug("🔵 BLEService: Write request for characteristic: \(request.characteristic.uuid), data: \(request.value?.count ?? 0) bytes")

            // Process the received data
            if let data = request.value {
                processReceivedData(data, from: request.central)
            }

            // Respond to the request
            peripheral.respond(to: request, withResult: .success)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEService: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            logger.error("🔵 BLEService: Failed to discover services: \(error.localizedDescription)")
            return
        }

        logger.info("🔵 BLEService: Discovered services for peripheral: \(peripheral.identifier)")

        guard let services = peripheral.services else { return }

        for service in services {
            if service.uuid == serviceUUID {
                logger.info("🔵 BLEService: Found mesh service, discovering characteristics")
                peripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            logger.error("🔵 BLEService: Failed to discover characteristics: \(error.localizedDescription)")
            return
        }

        logger.info("🔵 BLEService: Discovered characteristics for service: \(service.uuid)")

        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                logger.info("🔵 BLEService: Found mesh characteristic, setting up notifications")

                // Enable notifications
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("🔵 BLEService: Failed to update value for characteristic: \(error.localizedDescription)")
            return
        }

        guard let data = characteristic.value else { return }

        logger.debug("🔵 BLEService: Received data from peripheral: \(peripheral.identifier), \(data.count) bytes")

        // Process the received data
        processReceivedData(data, from: peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("🔵 BLEService: Failed to write value for characteristic: \(error.localizedDescription)")
        } else {
            logger.debug("🔵 BLEService: Successfully wrote value for characteristic: \(characteristic.uuid)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("🔵 BLEService: Failed to update notification state: \(error.localizedDescription)")
        } else {
            logger.info("🔵 BLEService: Notification state updated for characteristic: \(characteristic.uuid), isNotifying: \(characteristic.isNotifying)")
        }
    }
}

// MARK: - Data Processing

extension BLEService {

    private func processReceivedData(_ data: Data, from source: Any) {
        logger.debug("🔵 BLEService: Processing received data: \(data.count) bytes")

        // For now, just log the data
        // In a full implementation, this would parse the mesh protocol packets

        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.bleServiceDidReceiveData(data, from: source)
        }
    }

    func sendData(_ data: Data, to peripheral: CBPeripheral? = nil) {
        logger.debug("🔵 BLEService: Sending data: \(data.count) bytes")

        bleQueue.async { [weak self] in
            self?.performSendData(data, to: peripheral)
        }
    }

    private func performSendData(_ data: Data, to targetPeripheral: CBPeripheral?) {
        guard let peripheralManager = peripheralManager,
              let characteristic = meshCharacteristic else {
            logger.error("🔵 BLEService: Cannot send data - peripheral manager or characteristic not available")
            return
        }

        if let target = targetPeripheral {
            // Send to specific peripheral (if connected)
            if connectedPeripherals.contains(target) {
                // This would require a different approach for directed sends
                logger.info("🔵 BLEService: Sending data to specific peripheral: \(target.identifier)")
            }
        } else {
            // Broadcast to all connected peripherals
            logger.info("🔵 BLEService: Broadcasting data to all connected peripherals")

            // Update characteristic value
            characteristic.value = data

            // Notify all subscribed centrals
            let success = peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)

            if success {
                logger.debug("🔵 BLEService: Successfully broadcast data")
            } else {
                logger.warning("🔵 BLEService: Failed to broadcast data - queue full")
            }
        }
    }
}

// MARK: - BLEServiceDelegate Protocol

protocol BLEServiceDelegate: AnyObject {
    func bleServiceDidUpdateState(_ state: CBManagerState)
    func bleServiceDidUpdatePeripheralState(_ state: CBManagerState)
    func bleServiceDidConnectPeripheral(_ peripheral: CBPeripheral)
    func bleServiceDidFailToConnectPeripheral(_ peripheral: CBPeripheral, error: Error?)
    func bleServiceDidDisconnectPeripheral(_ peripheral: CBPeripheral, error: Error?)
    func bleServiceDidSubscribeToCharacteristic(_ characteristic: CBCharacteristic, central: CBCentral)
    func bleServiceDidUnsubscribeFromCharacteristic(_ characteristic: CBCharacteristic, central: CBCentral)
    func bleServiceDidReceiveData(_ data: Data, from source: Any)
}

// MARK: - CBManagerState Extension

extension CBManagerState {
    var debugDescription: String {
        switch self {
        case .unknown: return "unknown"
        case .resetting: return "resetting"
        case .unsupported: return "unsupported"
        case .unauthorized: return "unauthorized"
        case .poweredOff: return "poweredOff"
        case .poweredOn: return "poweredOn"
        @unknown default: return "@unknown"
        }
    }
}
