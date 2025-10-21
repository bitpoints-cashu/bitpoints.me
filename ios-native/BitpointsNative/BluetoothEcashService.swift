import Foundation
import CoreBluetooth

/// Bluetooth service for ecash token transfers
/// Full mesh networking implementation adapted from bitchat
class BluetoothEcashService: NSObject {
    
    // MARK: - Properties
    
    private let bleService: BLEService
    weak var delegate: BluetoothEcashServiceDelegate?
    
    // State tracking
    private var nickname: String = "Bitpoints User"
    private var unclaimedTokens: [[String: Any]] = []
    private var activePeers: [[String: Any]] = []
    private var availablePeers: [[String: Any]] = []
    
    // Message tracking
    private var pendingMessages: [String: [String: Any]] = [:]
    private var messageCounter: Int = 0
    
    // MARK: - Initialization

    override init() {
        self.bleService = BLEService()
        super.init()
        
        // Set up delegate
        bleService.delegate = self
        
        print("🔵 BluetoothEcashService: Initialized")
    }
    
    // MARK: - Public Interface
    
    func requestPermissions(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔵 BluetoothEcashService: Requesting permissions")
        
        // Proactively initialize BLE managers to trigger permission prompts
        let _ = CBCentralManager(delegate: nil, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        let _ = CBPeripheralManager(delegate: nil, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
        
        // Check authorization status
        let authStatus = CBCentralManager.authorization
        if authStatus == .allowedAlways || authStatus == .allowedWhenInUse {
            print("🔵 BluetoothEcashService: Permissions granted")
            completion(.success(()))
        } else {
            print("🔵 BluetoothEcashService: Permissions denied")
            completion(.failure(BluetoothEcashServiceError.permissionDenied))
        }
    }

    func startService(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔵 BluetoothEcashService: Starting service")
        bleService.startService()
            completion(.success(()))
    }

    func stopService(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔵 BluetoothEcashService: Stopping service")
        bleService.stopService()
            completion(.success(()))
    }
    
    func isBluetoothEnabled() -> Bool {
        let isPoweredOn = bleService.getCurrentBluetoothState() == .poweredOn
        let isAuthorized = CBCentralManager.authorization == .allowed
        print("🔵 BluetoothEcashService: isBluetoothEnabled - PoweredOn: \(isPoweredOn), Authorized: \(isAuthorized)")
        return isPoweredOn && isAuthorized
    }
    
    func sendToken(_ options: [String: Any], completion: @escaping (Result<String, Error>) -> Void) {
        print("🔵 BluetoothEcashService: Sending token with options: \(options)")
        
        guard let token = options["token"] as? String,
              let amount = options["amount"] as? Int,
              let unit = options["unit"] as? String,
              let senderNpub = options["senderNpub"] as? String else {
            completion(.failure(BluetoothEcashServiceError.invalidParameters))
            return
        }
        
        let peerID = options["peerID"] as? String
        let memo = options["memo"] as? String
        let mint = options["mint"] as? String ?? ""
        
        // Create message
        let messageId = "msg_\(UUID().uuidString)"
        let message: [String: Any] = [
            "id": messageId,
            "type": "ecash",
            "token": token,
            "amount": amount,
            "unit": unit,
            "senderNpub": senderNpub,
            "memo": memo ?? "",
            "mint": mint,
            "timestamp": Date().timeIntervalSince1970 * 1000,
            "targetPeerID": peerID ?? "broadcast"
        ]
        
        // Convert to data and send via BLE
        guard let data = try? JSONSerialization.data(withJSONObject: message) else {
            completion(.failure(BluetoothEcashServiceError.invalidData))
            return
        }
        
        bleService.sendData(data)
        
        // Track pending message
        pendingMessages[messageId] = message
        
        print("🔵 BluetoothEcashService: Token sent with messageId: \(messageId)")
        completion(.success(messageId))
    }
    
    func getActivePeers() -> [[String: Any]] {
        print("🔵 BluetoothEcashService: Getting active peers")
        return activePeers
    }
    
    func getAvailablePeers() -> [[String: Any]] {
        print("🔵 BluetoothEcashService: Getting available peers")
        return availablePeers
    }
    
    func getUnclaimedTokens() -> [[String: Any]] {
        print("🔵 BluetoothEcashService: Getting unclaimed tokens")
        return unclaimedTokens
    }
    
    func markTokenClaimed(messageId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔵 BluetoothEcashService: Marking token claimed: \(messageId)")
        
        // Remove from unclaimed tokens
        unclaimedTokens.removeAll { token in
            token["id"] as? String == messageId
        }
        
        // Remove from pending messages
        pendingMessages.removeValue(forKey: messageId)
        
        completion(.success(()))
    }
    
    func setNickname(_ nickname: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("🔵 BluetoothEcashService: Setting nickname to: \(nickname)")
        self.nickname = nickname
        completion(.success(nickname))
    }
    
    func getNickname() -> String {
        print("🔵 BluetoothEcashService: Getting nickname: \(nickname)")
        return nickname
    }
    
    func requestBluetoothEnable(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔵 BluetoothEcashService: Requesting Bluetooth enable")
        requestPermissions(completion: completion)
    }
    
    func sendTextMessage(message: String, toPeer peerID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔵 BluetoothEcashService: Sending text message to \(peerID): \(message)")
        
        // Create text message
        let messageId = "text_\(UUID().uuidString)"
        let textMessage: [String: Any] = [
            "id": messageId,
            "type": "text",
            "message": message,
            "senderNickname": nickname,
            "targetPeerID": peerID,
            "timestamp": Date().timeIntervalSince1970 * 1000
        ]
        
        // Convert to data and send via BLE
        guard let data = try? JSONSerialization.data(withJSONObject: textMessage) else {
            completion(.failure(BluetoothEcashServiceError.invalidData))
            return
        }
        
        bleService.sendData(data)
        completion(.success(()))
    }
    
    func openAppSettings(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔵 BluetoothEcashService: Opening app settings")
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                completion(.success(()))
                return
            }
        }
        completion(.failure(BluetoothEcashServiceError.failedToOpenSettings))
    }
    
    func startAlwaysOnMode(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔵 BluetoothEcashService: Starting always-on mode (iOS not supported)")
        completion(.success(()))
    }
    
    func stopAlwaysOnMode(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔵 BluetoothEcashService: Stopping always-on mode (iOS not supported)")
        completion(.success(()))
    }
    
    func isAlwaysOnActive() -> Bool {
        print("🔵 BluetoothEcashService: Checking always-on mode (iOS not supported)")
        return false
    }
    
    func requestBatteryOptimizationExemption(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔵 BluetoothEcashService: Requesting battery optimization exemption (iOS not supported)")
        completion(.success(()))
    }
    
    // MARK: - Private Methods
    
    private func processReceivedMessage(_ data: Data) {
        print("🔵 BluetoothEcashService: Processing received message: \(data.count) bytes")
        
        guard let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("🔵 BluetoothEcashService: Failed to parse received message")
            return
        }
        
        guard let messageType = message["type"] as? String else {
            print("🔵 BluetoothEcashService: Message missing type field")
            return
        }
        
        switch messageType {
        case "ecash":
            handleEcashMessage(message)
        case "text":
            handleTextMessage(message)
        case "peerInfo":
            handlePeerInfoMessage(message)
        default:
            print("🔵 BluetoothEcashService: Unknown message type: \(messageType)")
        }
    }
    
    private func handleEcashMessage(_ message: [String: Any]) {
        print("🔵 BluetoothEcashService: Handling ecash message")
        
        // Add to unclaimed tokens
        unclaimedTokens.append(message)
        
        // Notify delegate
        delegate?.bluetoothEcashService(self, didReceiveEcashMessage: message)
    }
    
    private func handleTextMessage(_ message: [String: Any]) {
        print("🔵 BluetoothEcashService: Handling text message")
        
        // Notify delegate
        delegate?.bluetoothEcashService(self, didReceiveTextMessage: message)
    }
    
    private func handlePeerInfoMessage(_ message: [String: Any]) {
        print("🔵 BluetoothEcashService: Handling peer info message")
        
        guard let peerID = message["peerID"] as? String,
              let nickname = message["nickname"] as? String else {
            return
        }
        
        let peerInfo: [String: Any] = [
            "peerID": peerID,
            "nickname": nickname,
            "lastSeen": Date().timeIntervalSince1970 * 1000,
            "isDirect": true,
            "nostrNpub": message["nostrNpub"] as? String ?? "",
            "isConnected": true
        ]
        
        // Update peer lists
        updatePeerInList(&activePeers, peerInfo)
        updatePeerInList(&availablePeers, peerInfo)
        
        // Notify delegate
        delegate?.bluetoothEcashService(self, didDiscoverPeer: peerInfo)
    }
    
    private func updatePeerInList(_ peerList: inout [[String: Any]], _ peerInfo: [String: Any]) {
        let peerID = peerInfo["peerID"] as! String
        
        if let index = peerList.firstIndex(where: { ($0["peerID"] as? String) == peerID }) {
            peerList[index] = peerInfo
        } else {
            peerList.append(peerInfo)
        }
    }
}

// MARK: - BLEServiceDelegate
extension BluetoothEcashService: BLEServiceDelegate {
    func bleServiceDidUpdateState(_ state: CBManagerState) {
        print("🔵 BluetoothEcashService: BLE state updated: \(state.debugDescription)")
        delegate?.bluetoothEcashService(self, didUpdateState: state)
    }
    
    func bleServiceDidUpdatePeripheralState(_ state: CBManagerState) {
        print("🔵 BluetoothEcashService: BLE peripheral state updated: \(state.debugDescription)")
        delegate?.bluetoothEcashService(self, didUpdatePeripheralState: state)
    }
    
    func bleServiceDidConnectPeripheral(_ peripheral: CBPeripheral) {
        print("🔵 BluetoothEcashService: Connected to peripheral: \(peripheral.identifier)")
        delegate?.bluetoothEcashService(self, didConnectPeripheral: peripheral)
    }
    
    func bleServiceDidFailToConnectPeripheral(_ peripheral: CBPeripheral, error: Error?) {
        print("🔵 BluetoothEcashService: Failed to connect to peripheral: \(peripheral.identifier), error: \(error?.localizedDescription ?? "unknown")")
        delegate?.bluetoothEcashService(self, didFailToConnectPeripheral: peripheral, error: error)
    }
    
    func bleServiceDidDisconnectPeripheral(_ peripheral: CBPeripheral, error: Error?) {
        print("🔵 BluetoothEcashService: Disconnected from peripheral: \(peripheral.identifier)")
        delegate?.bluetoothEcashService(self, didDisconnectPeripheral: peripheral, error: error)
    }
    
    func bleServiceDidSubscribeToCharacteristic(_ characteristic: CBCharacteristic, central: CBCentral) {
        print("🔵 BluetoothEcashService: Central subscribed to characteristic: \(characteristic.uuid)")
        delegate?.bluetoothEcashService(self, didSubscribeToCharacteristic: characteristic, central: central)
    }
    
    func bleServiceDidUnsubscribeFromCharacteristic(_ characteristic: CBCharacteristic, central: CBCentral) {
        print("🔵 BluetoothEcashService: Central unsubscribed from characteristic: \(characteristic.uuid)")
        delegate?.bluetoothEcashService(self, didUnsubscribeFromCharacteristic: characteristic, central: central)
    }
    
    func bleServiceDidReceiveData(_ data: Data, from source: Any) {
        print("🔵 BluetoothEcashService: Received data from source")
        processReceivedMessage(data)
        delegate?.bluetoothEcashService(self, didReceiveData: data, from: source)
    }
}

// MARK: - BluetoothEcashServiceDelegate Protocol
protocol BluetoothEcashServiceDelegate: AnyObject {
    func bluetoothEcashService(_ service: BluetoothEcashService, didUpdateState state: CBManagerState)
    func bluetoothEcashService(_ service: BluetoothEcashService, didUpdatePeripheralState state: CBManagerState)
    func bluetoothEcashService(_ service: BluetoothEcashService, didConnectPeripheral peripheral: CBPeripheral)
    func bluetoothEcashService(_ service: BluetoothEcashService, didFailToConnectPeripheral peripheral: CBPeripheral, error: Error?)
    func bluetoothEcashService(_ service: BluetoothEcashService, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?)
    func bluetoothEcashService(_ service: BluetoothEcashService, didSubscribeToCharacteristic characteristic: CBCharacteristic, central: CBCentral)
    func bluetoothEcashService(_ service: BluetoothEcashService, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic, central: CBCentral)
    func bluetoothEcashService(_ service: BluetoothEcashService, didReceiveData data: Data, from source: Any)
    func bluetoothEcashService(_ service: BluetoothEcashService, didReceiveEcashMessage message: [String: Any])
    func bluetoothEcashService(_ service: BluetoothEcashService, didReceiveTextMessage message: [String: Any])
    func bluetoothEcashService(_ service: BluetoothEcashService, didDiscoverPeer peerInfo: [String: Any])
}

// MARK: - BluetoothEcashServiceError
enum BluetoothEcashServiceError: Error, LocalizedError {
    case permissionDenied
    case invalidParameters
    case invalidData
    case failedToOpenSettings
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Bluetooth permissions were denied"
        case .invalidParameters:
            return "Invalid parameters provided"
        case .invalidData:
            return "Invalid data format"
        case .failedToOpenSettings:
            return "Failed to open app settings"
        case .unknown(let message):
            return message
        }
    }
}