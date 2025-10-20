import Foundation
import CoreBluetooth

/**
 * BluetoothEcashService
 *
 * Main service for handling Bluetooth ecash operations
 * iOS equivalent of Android's BluetoothEcashService.kt
 * Enhanced with complete mesh networking stack
 */
class BluetoothEcashService: NSObject, BLEServiceDelegate, MessageHandlerDelegate, PacketProcessorDelegate, PacketRelayManagerDelegate {

    weak var delegate: EcashDelegate?

    private var isServiceActive = false
    private var activePeers: [String: PeerInfo] = [:]
    private var unclaimedTokens: [EcashMessage] = []
    private var nickname: String = "Bitpoints User"

    // Core services
    private let bleService: BLEService
    private let noiseService: NoiseEncryptionService
    private let keychain: KeychainManagerProtocol
    
    // Mesh networking services
    private let connectionManager: ConnectionManager
    private let messageHandler: MessageHandler
    private let fragmentManager: FragmentManager
    private let packetProcessor: PacketProcessor
    private let packetRelayManager: PacketRelayManager
    private let securityManager: SecurityManager
    private let powerManager: PowerManager
    private let noiseSessionManager: NoiseSessionManager

    override init() {
        print("BluetoothEcashService initialized")

        // Initialize keychain
        self.keychain = KeychainManager()

        // Initialize noise service
        self.noiseService = NoiseEncryptionService(keychain: keychain)
        
        // Initialize mesh networking services
        self.connectionManager = ConnectionManager()
        self.fragmentManager = FragmentManager()
        self.messageHandler = MessageHandler(connectionManager: connectionManager, fragmentManager: fragmentManager)
        self.packetProcessor = PacketProcessor(connectionManager: connectionManager, messageHandler: messageHandler)
        self.packetRelayManager = PacketRelayManager(connectionManager: connectionManager, packetProcessor: packetProcessor)
        self.securityManager = SecurityManager()
        self.powerManager = PowerManager(connectionManager: connectionManager)
        self.noiseSessionManager = NoiseSessionManager(keychain: keychain)

        // Initialize BLE service
        self.bleService = BLEService(noiseService: noiseService, keychain: keychain)
        
        super.init()
        
        // Set up delegates
        self.bleService.delegate = self
        self.connectionManager.delegate = self
        self.messageHandler.delegate = self
        self.packetProcessor.delegate = self
        self.packetRelayManager.delegate = self
        self.securityManager.delegate = self
        self.powerManager.delegate = self

        // Set up noise service callbacks
        noiseService.onHandshakeRequired = { [weak self] peerID in
            self?.initiateHandshake(with: peerID)
        }
    }

    // MARK: - Service Control

    func startService(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🚀 Starting Bluetooth ecash service")

        bleService.startService()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isServiceActive = true
            completion(.success(()))
        }
    }

    func stopService(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🛑 Stopping Bluetooth ecash service")

        bleService.stopService()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isServiceActive = false
            completion(.success(()))
        }
    }

    // MARK: - Token Operations

    func sendToken(token: String,
                  toPeer: String,
                  amount: Int,
                  unit: String,
                  memo: String?,
                  completion: @escaping (Result<String, Error>) -> Void) {
        print("🚀 sendToken called from frontend")
        print("📦 Token received: \(token.prefix(20))...")
        print("Sending ecash token to peer \(toPeer)")

        let messageId = UUID().uuidString

        // Create ecash message
        let ecashMessage = EcashMessage(
            id: messageId,
            senderId: getMyPeerID(),
            recipientId: PeerID(str: toPeer),
            amount: amount,
            unit: unit,
            cashuToken: token,
            mint: "", // TODO: Extract mint from token
            memo: memo
        )

        do {
            // Create packet for sending
            let packetData = try messageHandler.createEcashMessage(ecashMessage, ttl: 7)
            
            // Send via BLE service
            bleService.sendData(packetData, to: PeerID(str: toPeer)) { [weak self] result in
                switch result {
                case .success:
                    print("✅ Token sent successfully to \(toPeer)")
                    completion(.success(messageId))
                    
                    // Notify frontend
                    DispatchQueue.main.async {
                        self?.delegate?.ecashService(self!, didSendToken: ecashMessage)
                    }
                    
                case .failure(let error):
                    print("❌ Failed to send token: \(error)")
                    completion(.failure(error))
                }
            }
            
        } catch {
            print("❌ Failed to create ecash packet: \(error)")
            completion(.failure(error))
        }
    }
    
    // MARK: - Token Receive Handling
    
    private func handleReceivedToken(_ ecashMessage: EcashMessage, from sender: PeerID) {
        print("📨 Received ecash token from \(sender)")
        
        // Add to unclaimed tokens
        unclaimedTokens.append(ecashMessage)
        
        // Auto-redeem token
        autoRedeemToken(ecashMessage) { [weak self] result in
            switch result {
            case .success:
                print("✅ Token auto-redeemed successfully")
                
                // Remove from unclaimed tokens
                self?.unclaimedTokens.removeAll { $0.id == ecashMessage.id }
                
                // Notify frontend
                DispatchQueue.main.async {
                    self?.delegate?.ecashService(self!, didReceiveToken: ecashMessage)
                }
                
            case .failure(let error):
                print("❌ Failed to auto-redeem token: \(error)")
                
                // Still notify frontend about received token
                DispatchQueue.main.async {
                    self?.delegate?.ecashService(self!, didReceiveToken: ecashMessage)
                }
            }
        }
    }
    
    private func autoRedeemToken(_ ecashMessage: EcashMessage, completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: Implement actual token redemption via Cashu mint
        // For now, simulate successful redemption
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            completion(.success(()))
        }
    }
    
    // MARK: - Peer Management
    
    func getActivePeers() -> [PeerInfo] {
        return Array(activePeers.values)
    }
    
    func getUnclaimedTokens() -> [EcashMessage] {
        return unclaimedTokens
    }
    
    // MARK: - Helper Methods
    
    private func getMyPeerID() -> PeerID {
        // Get peer ID from noise service
        let publicKeyData = noiseService.getStaticPublicKeyData()
        return PeerID(publicKey: publicKeyData)
    }
    
    // MARK: - Delegate Methods
    
    // MARK: - BLEServiceDelegate
    
    func bleService(_ service: BLEService, didReceiveData data: Data, from peerID: PeerID) {
        // Process incoming data through packet processor
        packetProcessor.processPacket(data, from: peerID, via: nil)
    }
    
    func bleService(_ service: BLEService, didConnectTo peerID: PeerID) {
        print("🔗 Connected to peer \(peerID)")
        
        // Add to active peers
        let peerInfo = PeerInfo(
            peerID: peerID,
            nickname: "Peer \(peerID.id.prefix(8))",
            isConnected: true,
            noisePublicKey: nil,
            signingPublicKey: nil,
            lastSeen: Date()
        )
        activePeers[peerID.id] = peerInfo
        
        // Notify frontend
        DispatchQueue.main.async {
            self.delegate?.ecashService(self, didConnectToPeer: peerInfo)
        }
    }
    
    func bleService(_ service: BLEService, didDisconnectFrom peerID: PeerID) {
        print("🔌 Disconnected from peer \(peerID)")
        
        // Update peer status
        if var peerInfo = activePeers[peerID.id] {
            peerInfo.isConnected = false
            activePeers[peerID.id] = peerInfo
        }
        
        // Notify frontend
        DispatchQueue.main.async {
            self.delegate?.ecashService(self, didDisconnectFromPeer: peerID)
        }
    }
    
    // MARK: - MessageHandlerDelegate
    
    func messageHandler(_ handler: MessageHandler, didReceiveEcash message: EcashMessage, from sender: PeerID) {
        handleReceivedToken(message, from: sender)
    }
    
    func messageHandler(_ handler: MessageHandler, didReceiveAnnounce message: IdentityAnnouncement, from sender: PeerID) {
        print("📢 Received announcement from \(sender)")
        
        // Update peer info
        let peerInfo = PeerInfo(
            peerID: sender,
            nickname: message.nickname,
            isConnected: false,
            noisePublicKey: message.noisePublicKey,
            signingPublicKey: message.signingPublicKey,
            lastSeen: Date()
        )
        activePeers[sender.id] = peerInfo
        
        // Notify frontend
        DispatchQueue.main.async {
            self.delegate?.ecashService(self, didDiscoverPeer: peerInfo)
        }
    }
    
    func messageHandler(_ handler: MessageHandler, didReceiveSync message: RequestSyncPacket, from sender: PeerID) {
        print("🔄 Received sync request from \(sender)")
        // TODO: Implement sync response
    }
    
    func messageHandler(_ handler: MessageHandler, didReceiveAck message: DeliveryAck, from sender: PeerID) {
        print("✅ Received delivery ack from \(sender)")
        // TODO: Handle delivery acknowledgment
    }
    
    func messageHandler(_ handler: MessageHandler, shouldRelayMessage data: Data, to peerID: PeerID) {
        // Relay message via BLE service
        bleService.sendData(data, to: peerID) { result in
            switch result {
            case .success:
                print("📡 Relayed message to \(peerID)")
            case .failure(let error):
                print("❌ Failed to relay message: \(error)")
            }
        }
    }
    
    // MARK: - PacketProcessorDelegate
    
    func packetProcessor(_ processor: PacketProcessor, shouldRelayPacket data: Data, to peerID: PeerID) {
        // Relay packet via BLE service
        bleService.sendData(data, to: peerID) { result in
            switch result {
            case .success:
                print("📡 Relayed packet to \(peerID)")
            case .failure(let error):
                print("❌ Failed to relay packet: \(error)")
            }
        }
    }
    
    // MARK: - PacketRelayManagerDelegate
    
    func packetRelayManager(_ manager: PacketRelayManager, shouldRelayPacket data: Data, to peerID: PeerID) {
        // Relay packet via BLE service
        bleService.sendData(data, to: peerID) { result in
            switch result {
            case .success:
                print("📡 Relayed packet to \(peerID)")
            case .failure(let error):
                print("❌ Failed to relay packet: \(error)")
            }
        }
    }
    
    // MARK: - SecurityManagerDelegate
    
    func securityManager(_ manager: SecurityManager, didDetectEvent event: SecurityManager.SecurityEvent) {
        print("🚨 Security event: \(event.eventType) from \(event.peerID) - \(event.details)")
        
        // Notify frontend about security events
        DispatchQueue.main.async {
            self.delegate?.ecashService(self, didDetectSecurityEvent: event)
        }
    }
    
    // MARK: - PowerManagerDelegate
    
    func powerManager(_ manager: PowerManager, didUpdatePowerSettings settings: PowerSettings) {
        print("🔋 Power settings updated: \(settings.powerMode), scan interval: \(settings.scanInterval)")
        
        // Update BLE service with new power settings
        // TODO: Implement power-aware BLE operations
    }
    
    // MARK: - ConnectionManagerDelegate
    
    func connectionManager(_ manager: ConnectionManager, didAddConnection peerID: PeerID) {
        print("➕ Added connection to \(peerID)")
    }
    
    func connectionManager(_ manager: ConnectionManager, didUpdateConnection peerID: PeerID, state: ConnectionManager.ConnectionState) {
        print("🔄 Updated connection to \(peerID): \(state)")
    }
    
    func connectionManager(_ manager: ConnectionManager, didRemoveConnection peerID: PeerID) {
        print("➖ Removed connection to \(peerID)")
    }
    
    func connectionManager(_ manager: ConnectionManager, didFailConnection peerID: PeerID, error: Error) {
        print("❌ Connection failed to \(peerID): \(error)")
    }
    
    func connectionManager(_ manager: ConnectionManager, shouldReconnect peerID: PeerID, peripheral: CBPeripheral) {
        print("🔄 Attempting reconnection to \(peerID)")
        // TODO: Implement reconnection logic
    }
}
        }
    }

    func getActivePeers() -> [PeerInfo] {
        let blePeers = bleService.getActivePeers()
        return blePeers.map { blePeer in
            PeerInfo(
                id: blePeer.peerID.id,
                nickname: blePeer.nickname,
                lastSeen: blePeer.lastSeen,
                isDirect: true, // BLE is always direct
                nostrNpub: nil,
                isConnected: blePeer.isConnected
            )
        }
    }

    func getUnclaimedTokens() -> [EcashMessage] {
        return unclaimedTokens.filter { !$0.claimed }
    }

    func markTokenClaimed(_ messageId: String) {
        if let index = unclaimedTokens.firstIndex(where: { $0.id == messageId }) {
            unclaimedTokens[index].claimed = true
        }
    }

    // MARK: - Identity Management

    func setNickname(_ nickname: String) {
        self.nickname = nickname
    }

    func getNickname() -> String {
        return nickname
    }

    // MARK: - Bluetooth Status

    func isBluetoothEnabled() -> Bool {
        // TODO: Check actual Bluetooth state
        return true
    }

    func requestBluetoothEnable(completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: Request Bluetooth enable
        completion(.success(()))
    }

    func requestPermissions(completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: Request Bluetooth permissions
        completion(.success(()))
    }

    // MARK: - Handshake Management

    private func initiateHandshake(with peerID: PeerID) {
        do {
            let handshakeData = try noiseService.initiateHandshake(with: peerID)
            bleService.sendMessage(handshakeData, to: peerID)
        } catch {
            print("BluetoothEcashService: Failed to initiate handshake: \(error)")
        }
    }
}
